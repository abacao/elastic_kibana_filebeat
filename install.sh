#!/bin/bash -x
# Bash script to install ElastiSearch, Kibana, Logstash and filebeat
# It will install all in an Centos 7.64b instance
#
# To use it, use the following URLs
#
# http://$HOST_IP:9200 for the API
# http://$HOST_IP:5601 for Kibana
#

HOST_IP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')


## ElasticSearch Config Repo
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

echo '[elasticsearch-5.x]
name=Elasticsearch repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md' > /etc/yum.repos.d/elastic.repo

## Kibana Config Repo
echo '[kibana-5.x]
name=Kibana repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md' > /etc/yum.repos.d/kibana.repo

## Logstash Config Repo
echo '[logstash-5.x]
name=Elastic repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md' > /etc/yum.repos.d/logstash.repo

yum update -y

yum install -y nano vim java elasticsearch kibana logstash

curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-5.0.2-x86_64.rpm
sudo rpm -vi filebeat-5.0.2-x86_64.rpm

## Enable Services
systemctl enable elasticsearch
systemctl enable kibana
systemctl enable logstash
systemctl enable filebeat

## Filebeat Config for Logstash
echo 'input {
  beats {
    port => 5044
  }
}

output {
  elasticsearch {
    hosts => "'$HOST_IP':9200"
    manage_template => false
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
    document_type => "%{[@metadata][type]}"
  }
}' > /etc/logstash/conf.d/logstash-filebeat.conf

systemctl restart elasticsearch
echo "Elastic:"; systemctl status elasticsearch | grep Active
sleep 10
systemctl restart kibana
echo "Kibana:"; systemctl status kibana | grep Active
sleep 10
systemctl restart logstash
echo "Logstash:";systemctl status logstash | grep Active
sleep 10
systemctl restart filebeat
echo "Filebeat:";systemctl status filebeat | grep Active


## Backup exsiting files
cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak
cp /etc/kibana/kibana.yml /etc/kibana/kibana.yml.bak
cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak

## Config files that work
echo 'cluster.name: marretas
node.name: ${HOSTNAME}
network.host: '$HOST_IP'
discovery.zen.ping.unicast.hosts: ["'$HOST_IP'"]' > /etc/elasticsearch/elasticsearch.yml

echo 'server.host: "'$HOST_IP'"
elasticsearch.url: "http://'$HOST_IP':9200"' > /etc/kibana/kibana.yml

echo 'filebeat.prospectors:
- input_type: log
  paths:
    - /var/log/*.log
output.logstash:
  # The Logstash hosts
  hosts: ["'$HOST_IP':5044"]' > /etc/filebeat/filebeat.yml

### Way to force logstash ##
## to run: /usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/logstash-simple.conf
echo 'input { stdin { } }
output {
  elasticsearch { hosts => ["'$HOST_IP':9200"] }
  stdout { codec => rubydebug }
}' > /etc/logstash/conf.d/logstash-simple.conf
