#!/bin/bash

set -e

if [ "${1:0:1}" != '-' ]; then
  exec "$@"
fi

# Get region from EC2 Metadata
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

# Retrieve parameters from the EC2 Parameter Store, decrypt the passwords with KMS key
# For this to work, you also need to make sure that the IAM Policy for the ECS Task or
# the IAM Instance Profile for the ECS host allows for the parameters to be retrieved and decrypted
SONARQUBE_JDBC_PASSWORD=`aws ssm get-parameters --names /passwords/devops_tools_rds_postgres_password --with-decryption --region $EC2_REGION --query 'Parameters[0].Value' | tr -d '"' 2>&1`
SONARQUBE_LDAP_PASSWORD=`aws ssm get-parameters --names /passwords/extenda_ldap_password --with-decryption --region $EC2_REGION --query 'Parameters[0].Value' | tr -d '"' 2>&1`

#chown -R sonarqube:sonarqube $SONARQUBE_HOME
exec gosu sonarqube \
  java -jar lib/sonar-application-$SONAR_VERSION.jar \
  -Dsonar.log.console=true \
  -Dsonar.jdbc.username="$SONARQUBE_JDBC_USERNAME" \
  -Dsonar.jdbc.password="$SONARQUBE_JDBC_PASSWORD" \
  -Dsonar.jdbc.url="$SONARQUBE_JDBC_URL" \
  -Dsonar.web.javaAdditionalOpts="$SONARQUBE_WEB_JVM_OPTS -Djava.security.egd=file:/dev/./urandom" \
  -Dsonar.security.realm=LDAP \
  -Dldap.url=ldap://dcsrv01.extenda.local \
  -Dldap.bindDn=ldapreader@extenda.local \
  -Dldap.bindPassword="$SONARQUBE_LDAP_PASSWORD" \
  -Dldap.user.baseDn=OU=Users,OU=EXTENDA_NG,DC=extenda,DC=local \
  -Dldap.user.request="(&(objectClass=user)(sAMAccountName={login}))" \
  -Dldap.user.realNameAttribute=cn \
  -Dldap.user.emailAttribute=mail \
  "$@"
