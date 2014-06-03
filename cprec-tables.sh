#!/bin/sh

db=$1

TIMESTAMP=$(date +"%F")

if [[ ! -f /root/.my.cnf ]]; then
	MYSQL="mysql -u root -p"
else
	MYSQL="mysql"
fi

tables=`$MYSQL -NB -e "SELECT TABLE_NAME FROM TABLES WHERE TABLE_SCHEMA='$db' and ENGINE='InnoDB'" information_schema`

for i in $tables
do
        #Check how many rows has a table
		rows=`$MYSQL -e "SELECT COUNT(*) FROM $i" -s $db`
		if [[ ! -f /var/lib/mysql/ibdata1.recovery ]]; then
			echo "/var/lib/mysql/ibdata1.recovery does not exist!"
		else
                # Prepare environment
                echo "Restoring table $i"
                table=$i
                perl create_defs.pl --host=localhost --user=root --password=`grep pass /root/.my.cnf | cut -d= -f2 | sed -e 's/^"//'  -e 's/"$//'` --db=$1 --table=$table > include/table_defs.h.$table
                cd include && rm -f table_defs.h && ln -s table_defs.h.$table table_defs.h
                cd ..
                make clean all
                # Restoring rows
                found=0
                while [ $found -lt 1 ]
                do
                        echo ""
                        ./constraints_parser -5 -f /var/lib/mysql/ibdata1.recovery >> out.$i
                        found=1
                done
		fi
done
