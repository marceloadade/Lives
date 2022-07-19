1. Install a Red Hat Linux VM
--Don't forget to checkpoint it

2. Install Postgres
link -> https://www.postgresql.org/download/linux/redhat/

	sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm <br>
	sudo dnf -qy module disable postgresql <br>
	sudo dnf install -y postgresql14-server <br>
	sudo /usr/pgsql-14/bin/postgresql-14-setup initdb <br>
	sudo systemctl enable postgresql-14 <br>
	sudo systemctl start postgresql-14 <br>

3. Configure postgres <br>
	edit postgresql.conf <br>
	find / -name "postgresql.conf" <br>
	/var/lib/pgsql/9.4/data/postgresql.conf <br>
	vim /var/lib/pgsql/9.4/data/postgresql.conf <br>
	add this -> listen_addresses = '*' <br>

	edit pg_hba.conf <br>
	add to the very end -> <br>
	host    all             all              0.0.0.0/0                       md5 <br>
	host    all             all              ::/0                            md5 <br>
	host    all             all              192.168.0.66/32(<-your ip here)   md5 <br>

	set the firewall to allow <br>
	firewall-cmd --permanent --zone=trusted --add-port=5432/tcp <br>
	firewall-cmd --reload <br>
	firewall-cmd --permanent --zone=trusted --add-source=192.168.0.207/32 <br>
	firewall-cmd --reload <br>

	you can also disable it to avoid issues with 

	create a super user 
	su - postgres
	pgsql
	CREATE ROLE username WITH LOGIN SUPERUSER PASSWORD 'password';

 4. Add some data <br>
	CREATE TABLE IF NOT EXISTS public.person <br>
	( <br>
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ), <br>
    first_name character varying(100) COLLATE pg_catalog."default" NOT NULL, <br>
    last_name character varying(100) COLLATE pg_catalog."default" NOT NULL, <br>
    email character varying(400) COLLATE pg_catalog."default" NOT NULL, <br>
    CONSTRAINT person_pkey PRIMARY KEY (id) <br>
	) <br>
	TABLESPACE pg_default; <br>

	insert into public.person(first_name,last_name,email)values('Don','Wright','dw@acme.com'); <br>
	insert into public.person(first_name,last_name,email)values('Richard','Monroe','richm@swampinc.com'); <br>
	insert into public.person(first_name,last_name,email)values('Lenore','Leane','lleane@vcloud.net'); <br>
	insert into public.person(first_name,last_name,email)values('Don','Wright','dw@acme.com'); <br>
	insert into public.person(first_name,last_name,email)values('Richard','Monroe','richm@swampinc.com'); <br>
	insert into public.person(first_name,last_name,email)values('Lenore','Leane','lleane@vcloud.net'); <br>
	insert into public.person(first_name,last_name,email)values('The Seventh','Charm','tsc@gmail.com'); <br>
	insert into public.person(first_name,last_name,email)values('The Eight','Working','ew@gmail.com'); <br>
	insert into public.person(first_name,last_name,email)values('The tenth','The tenth first','ttt@gmail.com'); <br>

	--check data <br>
	select * from person; <br>



5. Install the Confluent client
link -> https://packages.confluent.io/archive/7.2/?_ga=2.115818373.223632919.1658170586-1960284151.1647905570&_gac=1.148378181.1658170590.Cj0KCQjwidSWBhDdARIsAIoTVb1OuTxERpnT6YvQX8qIAoh3J4t_muPHmuAQrRaGkeTNOI-1HaTvubIaAjhmEALw_wcB
link -> https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html

cd /root
vim .bash_profile
export
export PATH= 

Install Java runtime
yum install java

disable firewall for the sake of demonstration:
systemctl stop firewalld
systemctl disable firewalld


6. Install debezium for postgres
https://docs.confluent.io/debezium-connect-postgres-source/current/overview.html
confluent-hub install debezium/debezium-connector-postgresql:latest

7. Install the JDBC driver for Sink data
https://docs.confluent.io/kafka-connect-jdbc/current/index.html
confluent-hub install confluentinc/kafka-connect-jdbc:latest

check all the plugins

confluent local services connect plugin list


7. Setup pgoutput as a Replication standard
https://debezium.io/documentation/reference/stable/connectors/postgresql.html#setting-up-postgresql

in postgresql.conf

#Replication
wal_level = logical  

restart postgres

setup permissions
create a superuser

9. Configure the connector for the Producer

vim postgres-debezium.json
{
    "name": "postgres-debezium",
    "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "localhost",
    "plugin.name": "pgoutput",
    "publication.name": "publication_debezium",
    "database.port": "5432",
    "database.user": "kafka",
    "database.password": "kafka",
    "database.dbname" : "producer",
    "database.server.name": "jupiter",
    "transforms": "unwrap",
    "transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.add.fields":"op,table,lsn,source.ts_ms",
    "transforms.unwrap.drop.tombstones": "false"
    }
   }

curl -X POST -H “Content-Type: application/json” — data @caminho-do-arquivo-json servidor-do-kafka-connect:porta-do-kafka-connect/connectors | jq -r
curl -X POST -H “Content-Type: application/json” --data @/etc/kafka-connect-postgresql/postgres.json localhost:8083/connectors | jq -r

curl -X POST -H "Content-Type: application/json" --data @/opt/stage/postgres-debezium.json localhost:8083/connectors | jq -r

curl localhost:8083/connectors/postgres-debezium/status | jq -r

kafka-topics --bootstrap-server=localhost:9092 --list 

kafka-console-consumer --bootstrap-server localhost:9092 --topic  --from-beginning

10. Configure the connector for the Consumer

vim jdbc-sqlserver-sink.json

{
        "name": "jdbc-sqlserver-sink",
        "config": {
            "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
            "tasks.max": "1",
            "key.converter": "io.confluent.connect.avro.AvroConverter",
            "key.converter.schema.registry.url": "http://localhost:8081",
            "value.converter": "io.confluent.connect.avro.AvroConverter",
            "value.converter.schema.registry.url": "http://localhost:8081",
            "header.converter": "org.apache.kafka.connect.storage.SimpleHeaderConverter",
            "topics": "jupiter2.public.person",
            "connection.url": "jdbc:sqlserver://192.168.0.207:1433;databaseName=pombo;",
            "connection.user": "kafka",
            "connection.password": "kafka",
            "insert.mode": "upsert",
            "pk.mode": "record_key",
            "pk.fields": "id",
            "auto.create": "true",
            "auto.evolve": "false",
            "max.retries": "1",
            "delete.enabled":"true",
            "transforms": "dropPrefix,unwrap",
            "transforms.dropPrefix.type": "org.apache.kafka.connect.transforms.RegexRouter",
            "transforms.dropPrefix.regex": "jupiter2\.public\.(.*)",
            "transforms.dropPrefix.replacement": "$1",
            "transforms.unwrap.type":  "io.debezium.transforms.ExtractNewRecordState",
            "transforms.unwrap.drop.tombstones": "false"
            }
        }

curl -X POST -H "Content-Type: application/json" --data @/opt/stage/jdbc-sqlserver-sink.json localhost:8083/connectors | jq -r

curl localhost:8083/connectors/jdbc-sqlserver-sink/status | jq -r

do soe stuff with the data in the origin: 


select * from person;

update person set email = 'pombo@gmail.com' where id = 8

delete from person where id = 10
