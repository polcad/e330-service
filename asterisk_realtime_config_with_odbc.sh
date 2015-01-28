#!/bin/bash
# Updated: 15.01.2015
# Dictador
# Asterisk Realtime configuration for OpenBTS with Sqlite3 and ODBC 
# http://www.fredshack.com/docs/asterisk.html
#
OPENBTS_ROOT = '/home/lenovo/.openbts'
sudo apt-get install libsqliteodbc unixodbc
#
# ODBC configuration files
#
#    /etc/odbcinst.ini
#
#    [SQLite3]
#    Description=SQLite3 ODBC Driver
#    Driver=/usr/lib/odbc/libsqlite3odbc.so
#    Setup=/usr/lib/odbc/libsqlite3odbc.so
#    Threading=2
#
#    /etc/odbc.ini
#
#    [asterisk]
#    Description=SQLite3 database
#    Driver=SQLite3
#    Database=/var/lib/asterisk/sqlite3dir/sqlite3.db
#    # optional lock timeout in milliseconds
#    Timeout=2000
#
cd /usr/local/etc; ln -s /etc/odbc.ini; ln -s /etc/odbcinst.ini
cd /root; ln -s /etc/odbc.ini .odbc.ini; ln -s /etc/odbcinst.ini .odbcinst.ini
cd $OPENBTS_ROOT; ln -s /etc/odbc.ini .odbc.ini; ln -s /etc/odbcinst.ini .odbcinst.ini

if [ -d "$/home/asterisk" ]; then
  cd /home/asterisk; ln -s /etc/odbc.ini .odbc.ini; ln -s /etc/odbcinst.ini .odbcinst.ini
fi


# modules.conf 
# extconfig.conf 
# res_odbc.conf 
# func_odbc.conf 
# extensions.conf 
# sip.conf

sudo chown -R asterisk:asterisk /var/lib/asterisk/sqlite3dir
