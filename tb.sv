// Code your testbench here
// or browse Examples
class transaction ;
rand bit [31:0] paddr ;
rand bit [7:0] pwdata ;
rand bit psel ;
randc bit penable ;
randc bit pwrite ;
bit [7:0] prdata ;
bit pready ;
bit pslverr ;

constraint addr_c { paddr>= 0 ; paddr<=15;}
constraint data_c  {pwdata>= 0 ; pwdata<= 255;}

function void display (input string tag) ;
$display("[%0s] :  paddr:%0d  pwdata:%0d pwrite:%0b  prdata:%0d pslverr:%0b @ %0t",tag,paddr,pwdata, pwrite, prdata, pslverr,$time);
   endfunction 
   endclass
   
   class generator ;
   transaction tr ;
   mailbox #(transaction ) mbx ; 
   event sconext , drvnext,done ;
   int count = 0 ;
   
   function new(mailbox #(transaction) mbx);
   this.mbx= mbx ;
   tr=new();
   endfunction 
   
   task run();
   repeat(count) begin
   assert(tr.randomize()) else $error("randomization failed") ;
   mbx.put(tr) ;
   tr.display("[GEN]");
   @(drvnext);
   @(sconext);
   end
   -> done ;
   
   endtask 
   
   endclass 
   
   class driver ;
   transaction tr ;
   virtual abp_if vif ;
   mailbox #(transaction) mbx;
   event  drvnext ;
   
   function new (mailbox #(transaction) mbx) ;
   this.mbx= mbx ;
   endfunction 
   
   task reset() ;
    vif.presetn <= 1'b0;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwdata  <= 0;
    vif.paddr   <= 0;
    vif.pwrite  <= 1'b0;
    repeat(5) @(posedge vif.clk);
    vif.presetn <= 1'b1;
    $display("[DRV] : RESET DONE");
    $display("----------------------------------------------------------------------------");
  endtask
   
   task run ();
   forever begin 
   mbx.get(tr);
   @(posedge vif.clk) ;
   if(tr.pwrite) begin   // write
   vif.psel<=1;
   vif.penable<=0 ;
   vif.pwdata<=tr.pwdata ;
   vif.paddr   <= tr.paddr;
   vif.pwrite<=1 ;
   @(posedge vif.clk) ;
   vif.penable<= 1 ;
   @(posedge vif.clk);
   vif.psel<=0;
   vif.penable <=0;
   vif.pwrite<= 0 ;
   tr.display("[DRV]");
   -> drvnext ;
   end
   
   else if(!tr.pwrite)   begin// read
   vif.psel <= 1 ;
   vif.penable <= 0 ;
   vif.pwdata<= 0 ;
   vif.paddr<= tr.paddr ;
   vif.pwrite <= 1'b0;
   @(posedge vif.clk);
   vif.penable <= 1 ;
   @(posedge vif.clk) ;
   vif.psel<=1'b0 ;
   vif.penable <= 0 ;
   vif.pwrite <= 0 ;
   tr.display("[DRV] ") ;
   -> drvnext ;
   end
   end
   endtask 
   
endclass 

class monitor ; 
virtual abp_if vif  ;
mailbox #(transaction ) mbx ;
transaction tr ;


function new(mailbox #(transaction) mbx ) ;
this.mbx=mbx ;
endfunction   

task run() ;
tr=new() ;
forever begin 
@(posedge vif.clk);
if(vif.pready)
begin
tr.pwdata = vif.pwdata ;
tr.paddr= vif.paddr ;
tr.pwrite = vif.pwrite ;
tr.prdata = vif.prdata ;
tr.pslverr = vif.pslverr ;
@(posedge vif.clk) ;
tr.display("[MON]");
mbx.put(tr);
end
end
endtask 

endclass


class scoreboard ; 
mailbox #(transaction) mbx ;
transaction tr ;
event sconext  ;
int err=0;

bit [7:0] pwdata [16] ='{default:0} ;
bit [7:0] rdata ;


function new(mailbox #(transaction) mbx) ;
this.mbx=mbx ;
endfunction

task run() ;
forever 
begin 

mbx.get(tr);
tr.display("[SCO]") ;

if((tr.pwrite) &&(!tr.pslverr))
begin
pwdata[tr.paddr] =tr.pwdata;
$display("[SCO] : Data stored data : %0d ADDR :%0d", tr.pwdata,tr.paddr);
end

else if((!tr.pwrite) &&(!tr.pslverr))
begin 
rdata = pwdata[tr.paddr];
if(tr.prdata==rdata)
$display("[SCO] : Data Matched");           
else
begin
err++;
$display("[SCO] : Data Mismatched");
end 
end 

else if(tr.pslverr) begin 
$display("[SCO] :SLV ERROR DETECTED") ;
end

$display("-----------------------------------------------");
-> sconext ;
end
endtask 

endclass 

class environment ;

generator gen ;
driver drv ;
monitor mon ;
scoreboard sco ;

event nextgd ;
event nextgs ;

mailbox #(transaction) gdmbx ;
mailbox #(transaction) msmbx ;

virtual abp_if vif ;

function new(virtual abp_if vif);
gdmbx=new() ;
gen=new(gdmbx);
drv=new(gdmbx) ;

msmbx = new();
mon=new(msmbx);
sco=new(msmbx);

this.vif=vif ;
drv.vif=this.vif;
mon.vif=this.vif ;

gen.sconext=nextgs ;
sco.sconext=nextgs;

gen.drvnext=nextgd ;
drv.drvnext=nextgd ;


endfunction 

task pre_test() ;
drv.reset() ;
endtask 

task test() ;
fork 
gen.run() ;
drv.run() ;
mon.run();
sco.run() ;
join_any
endtask 

task post_test() ;
wait(gen.done.triggered) ;
$display("--Total number of mismatch %0d",sco.err);
$finish ;
endtask 

task run() ;
pre_test() ;
test() ;
post_test() ;
endtask 

endclass 


   
module tb();
abp_if vif() ;
apb_s dut (
 vif.clk,
   vif.presetn,
   vif.paddr,
   vif.psel,
   vif.penable,
   vif.pwdata,
   vif.pwrite,
   vif.prdata,
   vif.pready,
   vif.pslverr
   );
   
   initial begin
   
   vif.clk <= 0 ;
   end
   
   always #10 vif.clk=~vif.clk ;
   
   environment env ;
   
   initial begin 
   env=new(vif) ;
   env.gen.count =20 ;
   env.run() ;
   end
   
initial begin 
  $dumpfile("dump.vcd");
  $dumpvars ;
end
endmodule
