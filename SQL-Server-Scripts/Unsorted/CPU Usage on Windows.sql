set nocount on;

if object_id('tempdb..#MeasureCPU') is not null
begin
  drop table #MeasureCPU
end
go
create table #MeasureCPU (
  CpuNumber tinyint identity(1, 1) not null
, MeasuredCPU varchar(100)
)
insert
into    #MeasureCPU (MeasuredCPU)
exec xp_cmdshell 'powershell.exe "Get-WmiObject win32_processor | select LoadPercentage  |fl" '

delete 
from    #MeasureCPU 
where   MeasuredCPU is null

update  #MeasureCPU 
set     MeasuredCPU = replace(MeasuredCPU, 'LoadPercentage : ', '')


select  row_number() over (order by CpuNumber) as cpu_number
      , MeasuredCPU as measured_cpu_percentage
      , getdate() as insert_date
from    #MeasureCPU
