# This is an individual project. In this project I tried to use some of the important SQL statements to find answers to some potentially asked questions.
# the goal is to mimic a social media (like a primitive extremely simplified instagram).
# we create a database containing three different tables. These tables are Users, photo, and comments.
# There will be 21 users, 50 photos and 100 comments (photos and comments are from the same users).
# tables are connected to each other through users table with primary key of user_id.
# In order to find the answers, we will write many different queries, use different types of joins, stored procedures, triggers, cursors, ...  


drop database if exists proj1;
create database proj1;
use proj1;
SET SQL_SAFE_UPDATES = 0;

create table users (
id int auto_increment primary key,
username varchar (30) not null,
created_at timestamp default now()
);

create table photo (
photo_id int auto_increment primary key,
user_id int,
photo_link varchar(100),
posted_at timestamp default now(),
foreign key (user_id) references users(id) ON DELETE CASCADE
);

create table comments (
user_id int,
photo_id int,
comment_id int auto_increment primary key,
comment_body varchar (1000),
foreign key (user_id) references users(id) ON DELETE CASCADE, 
foreign key (photo_id) references photo(photo_id) ON DELETE CASCADE
);

-- filling users : Since users are supposed to have different meaningful usernames and joining dates, we manually fill this table.
insert into users (id, username) values (1, 'Xaero');
insert into users (username) values ('Toomar'),('gonde'), ('HHH');
insert into users (username, created_at) values ('pouria', '2021-12-06'), ('sepide', '2022-04-11'), ('Shayan', '2019-1-4'),('farbod', '2017-08-02'),('casper', '2018-09-17'),('abbas', '2022-04-21'),('brandibelle', '2014-11-01'),('lil', '2018-12-08'),('Blackrollis', '2019-02-12'),('reaper', '2017-08-12'),('joker', '2008-04-18'),('ml_master', '2007-02-14'),('Yassel', '1999-01-17'),('most hated', '2012-07-11'),('T-rex', '1986-04-19'),('Matrix', '2009-06-22'),('Momentum', '2007-10-4');

-- filling photos :

# its easier to define a stored procedure to fill the photos table. We will do that in the following:
Delimiter //
create procedure photo_filler(inout inp int)
begin
	declare x int;
	set x = 0;
	photo_gen: loop
	set x = x+1;
		if x> inp then
			leave photo_gen;
		end if;
	insert into photo (user_id, photo_link) values (FLOOR(RAND() * 21)+1, concat('https://', SUBSTR(MD5(rand()),1, 10)));
	iterate photo_gen;

	end loop;
end //
Delimiter ;

set @inp = 50;
call photo_filler(@inp);

# comments can also be numerous. They can be written under any photo posted by any user in social media. Filling comments table is also easier and faster with a loop:
-- select FLOOR(RAND() * @inp)+1;
-- drop procedure comment_filler;

Delimiter //
create procedure comment_filler(in inpcm int)
begin
	declare x int;
	set x = 0;
	cm_gen: loop
	set x = x+1;
		if x> inpcm then
			leave cm_gen;
		end if;
	insert into comments (user_id, photo_id, comment_body) values (FLOOR(RAND() * 21)+1, FLOOR(RAND() * @inp)+1, substring(MD5(RAND()),1,200));
	iterate cm_gen;

	end loop;
end //
Delimiter ;

call comment_filler(100);


# ALRIGHT! so far we have 21 users that posted 50 photos, and then these users wrote 100 comments under those posted photos.
# now by writing queries, we wanna answer some questions that will come to mind.

#################################### who created the first account, how many days ago? and what was that day (in week)?

select *, dayname(created_at) as day_of_week from users order by created_at limit 1;
select min(created_at), datediff(now(), min(created_at)) as diff_in_days from users;

#################################### Which users posted the most photos ?

select users.id, username, count(photo_id) as photo_count from users join photo on users.id = photo.user_id group by users.id order by photo_count desc;

-- so we know that joker posted the most photos on social media.alter (though it is subject to change every time we run the tab, as the tables are filled with random filler procedures)

#################################### whose photos got the most comments ?

select users.id, username, count(comment_id) as cm_count 
from users join photo 
on users.id = photo.user_id join comments 
on users.id = comments.user_id 
group by users.id order by cm_count desc;

-- when I ran the query reaper got the mostcomments on her/his posts.

#################################### now we wanna choose top 3 users with the most comments ?

with query as (select users.id, username, count(comment_id) as cm_count 
from users join photo 
on users.id = photo.user_id join comments 
on users.id = comments.user_id 
group by users.id order by cm_count desc)
select username, cm_count from query having cm_count >20;

#################################### add a comment column based on how the usernames look !

select username, id,
case when username like '%eap%' || username like '%jok%' then 'looks like a gaming nickname ;)'
when username like 'T-rex' then 'Raaaaaawwwwr Dinosaur'
when username like 'HHH' then 'Time to play the game'
end as auto_generated_cm from users;

#################################### create a table to store all changes made into users table (joining, leaving, username changes) !
-- now we define some triggers to record any changes on the users table. These changes are stored in another table called users_history:

create table users_history(
id int auto_increment primary key,
old_username varchar (100),
new_username varchar (100) default null,
action varchar (15),
action_date datetime default null
);

create trigger update_history
before update on users
for each row
insert into users_history
set action = 'update',
old_username = old.username,
new_username = new.username,
action_date = now();

create trigger delete_history
before delete on users
for each row
insert into users_history
set action = 'delete',
old_username = old.username,
-- new_username = new.username,
action_date = now();

create trigger insert_history
before insert on users
for each row
insert into users_history
set action = 'joined',
-- old_username = old.username,
new_username = new.username,
action_date = now();

-- Testing triggers :

-- delete from users where username = 'Blackrollis';
-- update users set username = 'Tricerotops' where username = 'T-rex';
-- insert into users (username) values ('Quad');

-- select * from users_history;
##################################### write an html report to a supervisor to show when every username joined our social media !
# now we use a cursor to iterate through the results of a query, and provide a report about the users !

drop procedure if exists report;
Delimiter //
create procedure report(in lim int)
begin
	declare finished int default 0;
	declare user varchar(100);
	declare time timestamp;
    declare report_sheet varchar (5000);
    declare cur cursor for select username from users limit lim;
    declare tim cursor for select created_at from users limit lim;
    declare continue handler for not found set finished = 1;
    set report_sheet = '';
    
    open cur;
    open tim;
	iterator: loop
    fetch cur into user;
    fetch tim into time;
		if finished = 1 then
			leave iterator;
		end if;
        set report_sheet = concat (report_sheet, 'user ', user, 'created their account on ', time, ' - ');
	-- into comments (user_id, photo_id, comment_body) values (FLOOR(RAND() * 21)+1, FLOOR(RAND() * @inp)+1, substring(MD5(RAND()),1,200));
	iterate iterator;

	end loop;
    close cur;
    select report_sheet;
end //
Delimiter ;

call report (20);
# now we can exportthe results as an html file.
