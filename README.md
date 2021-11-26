# Use case JenkinsOnAzure: a server with Jenkins CI/CD on Azure with terraform

Use case for putting Jenkins CI/CD on Azure with terraform/ansible.

## Build the image

Prepare *credentials/id_rsa.pub* public key file to enable ssh connection to VM from your own system (as well as from container via ssh auth socket forwarding, see below).

```bash
docker build --file Dockerfile --tag=strokovnjaka/uc2jenkins --build-arg TERRAFORM_VERSION=1.0.11 .
```

## Test image

### Run container

Prepare *credentials/azure.env* from the template file.

On MacOSX use the following for correct ssh auth socket forwarding:

```bash
docker run -itd -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock -e SSH_AUTH_SOCK="/run/host-services/ssh-auth.sock" --env-file "credentials/azure.env" --name uc2jenkins strokovnjaka/uc2jenkins
```

On other systems probably something like: 

```bash
docker run -itd -v $(dirname $SSH_AUTH_SOCK) -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK --env-file "credentials/azure.env" --name uc2jenkins strokovnjaka/uc2jenkins
```

### Step into container

```bash
docker exec -it uc2jenkins /bin/bash
```

### Run terraform in container

```bash
terraform init
terraform apply
```

Outputs are *public_ip* and *initialpwd*. 
Go to `[public_ip]:8080` in your browser to setup Jenkins, use *initialpwd* to login the first time.

## Push image to Docker Hub

```bash
docker push strokovnjaka/uc2jenkins
```