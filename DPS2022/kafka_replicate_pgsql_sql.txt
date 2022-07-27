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



 5. Install the Confluent client: <br>
	link -> https://packages.confluent.io/archive/7.2/?_ga=2.115818373.223632919.1658170586-1960284151.1647905570&_gac=1.148378181.1658170590.Cj0KCQjwidSWBhDdARIsAIoTVb1OuTxERpnT6YvQX8qIAoh3J4t_muPHmuAQrRaGkeTNOI-1HaTvubIaAjhmEALw_wcB
	link -> https://docs.confluent.io/platform/current/quickstart/ce-docker-quickstart.html

	cd /root <br>
	vim .bash_profile <br>
	add to the file -> <br>
	export CONFLUENT_HOME=/opt/confluent-7.2.0 --The path to your confluent home here! <br>
	export PATH=$PATH:$CONFLUENT_HOME/bin
	:wq! <- to write the file
	
	to reload the profile:
	source ~/.bash_profile

	Install the Java runtime:
	yum install java

	disable firewall for the sake of the demonstration: <br>
	systemctl stop firewalld <br>
	systemctl disable firewalld <br>


  6. Install debezium for postgres <br>
	https://docs.confluent.io/debezium-connect-postgres-source/current/overview.html <br>
	confluent-hub install debezium/debezium-connector-postgresql:latest <br>

  7. Install the JDBC driver for Sink data <br>
	https://docs.confluent.io/kafka-connect-jdbc/current/index.html <br>
	confluent-hub install confluentinc/kafka-connect-jdbc:latest <br>

   check all the plugins <br>

   confluent local services connect plugin list <br>


  8. Setup pgoutput as a Replication standard <br>
  https://debezium.io/documentation/reference/stable/connectors/postgresql.html#setting-up-postgresql <br>
  in postgresql.conf <br>

  #Replication <br>
  wal_level = logical <br>

  restart postgres <br>

  setup permissions <br>
  create a superuser <br>

  9. Configure the connector for the Producer <br>

  vim postgres-debezium.json <br>
{ <br>
    "name": "postgres-debezium", <br>
    "config": { <br>
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector", <br>
    "database.hostname": "localhost", <br>
    "plugin.name": "pgoutput", <br>
    "publication.name": "publication_debezium", <br>
    "database.port": "5432", <br>
    "database.user": "kafka", <br>
    "database.password": "kafka", <br>
    "database.dbname" : "producer", <br>
    "database.server.name": "jupiter", <br>
    "transforms": "unwrap", <br>
    "transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState", <br>
    "transforms.unwrap.add.fields":"op,table,lsn,source.ts_ms", <br>
    "transforms.unwrap.drop.tombstones": "false" <br>
    } <br>
   } <br>

   curl -X POST -H “Content-Type: application/json” — data @caminho-do-arquivo-json servidor-do-kafka-connect:porta-do-kafka-connect/connectors | jq -r <br>
   curl -X POST -H “Content-Type: application/json” --data @/etc/kafka-connect-postgresql/postgres.json localhost:8083/connectors | jq -r <br>

   curl -X POST -H "Content-Type: application/json" --data @/opt/stage/postgres-debezium.json localhost:8083/connectors | jq -r <br>

   curl localhost:8083/connectors/postgres-debezium/status | jq -r <br>

   kafka-topics --bootstrap-server=localhost:9092 --list  <br>

   kafka-console-consumer --bootstrap-server localhost:9092 --topic  --from-beginning <br>

  10. Configure the connector for the Consumer <br>

  vim jdbc-sqlserver-sink.json <br>

  { <br>
        "name": "jdbc-sqlserver-sink", <br>
        "config": { <br>
            "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector", <br>
            "tasks.max": "1", <br>
            "key.converter": "io.confluent.connect.avro.AvroConverter", <br>
            "key.converter.schema.registry.url": "http://localhost:8081", <br>
            "value.converter": "io.confluent.connect.avro.AvroConverter", <br>
            "value.converter.schema.registry.url": "http://localhost:8081", <br>
            "header.converter": "org.apache.kafka.connect.storage.SimpleHeaderConverter", <br>
            "topics": "jupiter2.public.person", <br>
            "connection.url": "jdbc:sqlserver://sqlserverip:1433;databaseName=<<dbname>>;", <br>
            "connection.user": "kafka", <br>
            "connection.password": "password", <br>
            "insert.mode": "upsert", <br>
            "pk.mode": "record_key", <br>
            "pk.fields": "id", <br>
            "auto.create": "true", <br>
            "auto.evolve": "false", <br>
            "max.retries": "1", <br>
            "delete.enabled":"true", <br>
            "transforms": "dropPrefix,unwrap", <br>
            "transforms.dropPrefix.type": "org.apache.kafka.connect.transforms.RegexRouter", <br>
            "transforms.dropPrefix.regex": "jupiter2.public.(.*)", <br>
            "transforms.dropPrefix.replacement": "$1", <br>
            "transforms.unwrap.type":  "io.debezium.transforms.ExtractNewRecordState", <br>
            "transforms.unwrap.drop.tombstones": "false" <br>
            } <br>
        } <br>

curl -X POST -H "Content-Type: application/json" --data @/opt/stage/jdbc-sqlserver-sink.json localhost:8083/connectors | jq -r <br>

curl localhost:8083/connectors/jdbc-sqlserver-sink/status | jq -r <br>
 
do soe stuff with the data in the origin:  <br>

--shuffle some data <br>
select * from person; <br>

update person set email = 'pombo@gmail.com' where id = 8 <br>

delete from person where id = 10 <br>
