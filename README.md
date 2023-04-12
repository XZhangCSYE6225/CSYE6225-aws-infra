# aws-infra  
 

## Prerequisites  
1. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)  
2. [Terraform CLI](https://developer.hashicorp.com/terraform/downloads)  



## Initialize step
1. Configure AWS CLI use particular profile with access key and secret access key  
2. Clone the repo from github  
```sh
cd ~/
mkdir -p ./workspace/csye6225
```
3. Clone the repo and get into the directory of the repo
```sh
git clone git@github.com:XZhangCSYE6225/aws-infra.git
cd ./aws-infra
```
4. Edit the main.tf if any variables need to be changed
```sh
vim ./main.tf
```
5. Check the format
```sh
terraform fmt
```
6. Init and plan
```sh
terraform init && terraform plan
```
7. Apply
```sh
terraform apply
```

## The command to import the certificate
```sh
aws --profile demo --region us-east-1 acm import-certificate \
--certificate fileb://prod_xiaozhang99_me.crt \
--certificate-chain fileb://prod_xiaozhang99_me.ca-bundle \
--private-key fileb://private.pem     
```