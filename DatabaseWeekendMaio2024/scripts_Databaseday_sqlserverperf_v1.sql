--First stage
use StackOverflow2013
GO

--check a data sample
select top 100 * from Comments;

--select some data
select top 100 Text,CreationDate from Comments;

--select some data with filtering
--include actual plan
select Text,CreationDate from Comments
where Score > 10;
--2 segundos

--create an index to support this filter, version 1:
create nonclustered index ix_comments_score_01 on Comments(score)
--1:19
--drop index ix_comments_score_01 on Comments

--check again
--include actual plan
select Text,CreationDate from Comments
where Score > 10;
--2 segundos

--vamos incrementar:
set statistics io, time on

--desconsiderar o indice:
select Text,CreationDate from Comments
with (forcescan)
where Score > 10;
--7 segundos
--logical reads 994465

--considerar o indice:
select Text,CreationDate from Comments
where Score > 10;
--2 segundos
--logical reads 293691

set statistics io, time off
--improve the index, version 2:
create nonclustered index ix_comments_score_01 on Comments(score) include (Text,CreationDate)
with drop_existing;
--6:50

--try again
--include actual plan
set statistics io, time on
GO

select Text,CreationDate from Comments
where Score > 10;

set statistics io, time off

--adjust the index 
create nonclustered index ix_comments_score_01 on Comments(score) 
with drop_existing;
--45 secs
-------------------------------------------------------------------------------------------------------

--get data distribution insights
select count(score),score from Comments
group by score
order by 1 desc
--score 307 has 1 value
--score 0 has 20518256 values
--score 2 has 761776 values
--score 9 has 15951 values

GO

--create procedure for testing
create procedure p_get_score
@score int
as
begin

select Text,CreationDate from Comments
where Score = @score;

end
--end of procedure creation


--include plan and evaluate time
exec p_get_score @score = 307;

exec p_get_score @score = 2;

--optimize
exec p_get_score @score = 2 with recompile;

--raise compatibility to 2022
alter database StackOverflow2013 set compatibility_level = 160;
GO
ALTER DATABASE StackOverflow2013
SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO
);

--check again:
exec p_get_score @score = 3;

--revert db back to 2008 compatibility
alter database StackOverflow2013 set compatibility_level = 100;
GO

select name, compatibility_level
from sys.databases;

--dbcc freeproccache

--------------------------------------------------------------------------------------------------------------
--second stage
use StackOverflow2013
GO

select top 10 * from Comments;
select top 10 * from Votes;
select top 10 * from VoteTypes;
select top 10 * from Users;

--more joins:
select --top 10
c.text,
c.CreationDate,
u.DisplayName as UserName,
vt.Name as VoteName
from Comments c join Users u on u.Id = c.UserId
join Votes v on v.PostId = c.PostId
join VoteTypes vt on vt.Id = v.VoteTypeId


--less joins:
select top 10
c.text,
c.CreationDate,
u.DisplayName as UserName
from Comments c join Users u on u.Id = c.UserId
where c.Score > 10;

--create an index on the "FK"
create index ix_comments_uid_01 on Comments(UserId) include (text,CreationDate)
with ( online = on, resumable = on, maxdop = 24 )
--1:40
--drop index ix_comments_uid_01 on Comments

--adjust the index on comments
create nonclustered index ix_comments_score_01 on Comments(score,userid) include (text,creationdate)  
with ( online = on, resumable = on, maxdop = 24, drop_existing= on);
--7 mins

--test and check again
select --top 10
c.text,
c.CreationDate,
u.DisplayName as UserName
from Comments c join Users u on u.Id = c.UserId
where c.Score = 10; 
--------------------------------------------------------------------------

--different queries, same result
select * from Users

select DisplayName from Users where Reputation between 100 and 150
union
select DisplayName from Users where Reputation between 151 and 200

select DisplayName from Users where Reputation between 100 and 150
union all
select DisplayName from Users where Reputation between 151 and 200


--checking the object a table pertains to
dbcc traceon (3604);
dbcc page('StackOverFlow2013',1,541615,2)
dbcc traceoff (3604);
GO

select object_name(85575343)

dbcc traceon (3604);
dbcc page('master',1,1,0);
dbcc traceoff (3604);
GO

select * from sys.dm_db_page_info














-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
--control queries
select * from sys.indexes
select * from sys.objects

--Check indexes
select object_name(ix.object_id) as ObjName,
ix.name, 
ix.index_id, 
ix.type_desc,
ob.is_ms_shipped
from sys.indexes ix join sys.objects ob on ob.object_id = ix.object_id
where ob.is_ms_shipped = 0;


--Check index sizes
select object_name(ix.object_id) as ObjName,
ix.name, 
ix.index_id, 
ix.type_desc,
sum(ps.used_page_count)/128 as MB
from sys.indexes ix join sys.objects ob on ob.object_id = ix.object_id
join sys.dm_db_partition_stats ps on ps.object_id = ix.object_id and ps.index_id = ix.index_id
where ob.is_ms_shipped = 0
group by 
object_name(ix.object_id),
ix.name, 
ix.index_id, 
ix.type_desc
order by MB desc

select (37433*1024)/8






