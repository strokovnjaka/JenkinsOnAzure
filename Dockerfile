FROM alpine:latest
LABEL maintainer jaka

# version e.g. 1.0.11
ARG TERRAFORM_VERSION

RUN apk add --update --no-cache wget unzip curl git bash openssh

## Terraform
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -P /tmp
RUN unzip /tmp/terraform*.zip -d /usr/bin/ && rm -f /tmp/terraform*.zip

## Azure cli
RUN apk add --no-cache --virtual=build gcc libffi-dev musl-dev openssl-dev python3-dev py3-pip py3-pynacl rpm
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc
COPY azure-cli.repo /etc/yum.repos.d/azure-cli.repo
RUN pip install --upgrade pip
RUN pip install azure-cli

## Ansible
RUN pip install ansible

## Copy credentials, tf data, auto az login
COPY credentials/id_rsa.pub /root/.ssh/id_rsa.pub
COPY vps/ /vps/
COPY .bashrc /root/
