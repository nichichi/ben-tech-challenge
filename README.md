# ben-tech-challenge
## Overview
This repository contains the code and templates to build and deploy a simple REST API With NodeJS and Express.  
  
The application has a single endpoint **/health** with a GET method that returns the following:
- appname 
- version 
- hash
  
The application is Dockerised and deployed to AWS. The Terraform Templates deploy the infrastructure which includes the following resources: 
| Network Components | Container Components | Front-end Components |
| :---               | :---                 |:---                  |
| VPC                | ECS Cluster          | Load Balancer        |
| Internet Gateway   | Task Definition      | Target Group         |
| Public Subnets     | Execution Role       | HTTP Listener        |
| Route Table, Routes and Route Associations | ECS Service       | |
| Security Groups and Rules |                                    | |
  
## Usage
### Fork the Repo
1. Fork the GitHub Repo  
   ```
   # Follow The Instructions at this link to Fork the ben-tech-challenge-repo to your GitHub User Account
   https://docs.github.com/en/get-started/quickstart/fork-a-repo
   
   # Clone the forked repo
   git clone https://github.com/${your username}/${your forked repo}.git  
   ```
2. Verify the remote settings so that any changes you commit will be pushed to your forked repo and not the parent  
   ```
   git remote -v
   
   # Should return values as below
   # origin  https://github.com/${your username}/${your forked repo}.git  (fetch)
   # origin  https://github.com/${your username}/${your forked repo}.git  (push)
   ```

### Deploy to Local Environment  
There is a script to build and run the application inside Docker in your local environment. This is for building and testing the **nodejs application only**. It does not push the image to Docker Hub or deploy the AWS resources.  
  
The script accepts two arguments APPNAME and CONTEXT where CONTEXT is the full path to the app folder, this arg does not accept aliases like ~  
  
To get started navigate to the scripts folder and run ./init.sh APPNAME CONTEXT e.g.
```
cd ${your forked repo}/scripts/

# Usage: ./init.sh ${APPNAME} ${CONTEXT}
./init.sh ben-tech-challenge /home/ec2-user/environment/ben-tech-challenge/app

# To test the app is running
curl http://localhost/health # Should return something like {"githash":"d1f31a6","appname":"ben-tech-challenge","version":"v1.1-45-gd1f31a6"}

# Clean up - container name = ${APPNAME}
docker stop ben-tech-challenge
docker rm ben-tech-challenge
```  
  
### Deploy with CI/CD Pipeline 
I have utilised GitHub actions to automate deployments to AWS when changes are made to the **app | terraform | github workflow** and pushed to my GitHub repo  
  
To replicate this there are a couple of pre-requisites that are required; 
- DockerHub Account
- DockerHub Repo
- AWS IAM User with Secret Key, Access Key, and IAM permissions for creating/destroying the Terraform resources
- S3 Bucket to store Terraform State Files  
  
To help with the IAM Permissions I have included an identity based policy **extras/deploy-execution-policy.json**  
This policy contains the minimum permissions required to create and delete the Terraform resources. To use the policy make sure to replace all instances of **${REGION}** with the AWS region you are deloying to, and **${AWS_ACCOUNT_ID}** with your AWS Account ID before attaching the policy to an IAM group that your AWS IAM User is a member of.

**Note:** This policy does not contain the permissions required for viewing the resources in the AWS console
  
Also in the extras folder is a Cloudformation Template **cloudformation/prerequisites.yaml** to deploy the S3 Bucket for the Terraform backend. You can use this if you want but you will need to ensure that your user has permissions to deploy cloudformation stacks and the s3 resources it deploys.  
  
**Instructions**  
1. Create GitHub Repo Secrets  
   ```
   # Follow the Instructions at this link to create the below secrets: https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository
   # NOTE: GitHub Secrets CANNOT be retrieved in the GitHub Console, and CANNOT be output in plaintext in your workflow. Ensure you have a backup of your secrets.  
     
   AWS_ACCESS_KEY_ID=${your iam user access key id}
   AWS_SECRET_ACCESS_KEY=${your iam user secret access key}
   DOCKER_PASSWORD=${your docker hub password}
   DOCKER_USER=${your docker hub username}
   ```
2. Set Variables in Files  
   You can use the default values (as long as the network cidr ranges don't clash with your current environment) just make sure to update the **docker repo** and **s3 backend**, and check the AWS region and availability zones
   ```
   # in .github/workflows/deploy.yaml lines 12-14
   APPNAME: "ben-tech-challenge"
   DOCKER_REPO: "${your docker repo}"
   PORT: 80
   
   # in terraform/local.tfvars
   appname = "ben-tech-challenge"
   environment = "local"
   region = "ap-southeast-2"
   profile = "default"
   cidr = "10.0.0.0/24"
   private1Cidr = "10.0.0.0/26"
   private2Cidr = "10.0.0.64/26"
   public1Cidr = "10.0.0.128/26"
   public2Cidr = "10.0.0.192/26"
   containerPort = 80 # make sure this matches your port in .github/workflows/deploy.yaml
   albPort = 80
   availabilityZoneA = "ap-southeast-2a"
   availabilityZoneB = "ap-southeast-2b"
   dockerRepo = "${your docker repo}"
   cpu = 256
   memory = 512
   publicIp = true
   
   # in terraform/_backend.tf lines 3-5
   bucket = "${your s3 bucket}"
   key = "ben-tech-challenge/tfstatefiles"
   region = "ap-southeast-2"
   ```
3. Trigger Deploy  
   The deploy workflow will be triggered when commits are pushed to the main branch. To add additional branches edit the branches list on line 3 of .github/workflows/deploy.yaml
   ```
   # Example git commands to trigger a deployment
   git add .github/workflows/deploy.yaml terraform/local.tfvars terraform/_backend.tf
   git commit -m "Changed variables to point to my docker repo and s3 bucket"
   git push origin main
   
   # To view the deployment run output go to https://github.com/${your github user}/${your forked repo name}/actions/workflows/deploy.yaml select the run you want to view, and click on deploy (under jobs on the left hand side).
   ```
  
  
**Test**  
1. Check the Target Group is Healthy  
   In the AWS Console EC2 -> Target groups -> Select the target group and view Health status for the registered target e.g.
   ![image](https://user-images.githubusercontent.com/7879884/151684214-d03ec96c-d2a5-4ba8-b3de-ac54275162b3.png)

2. Retrieve the DNS Name of your Application Load Balancer  
   In the AWS Console EC2 -> Load Balancers -> Select the load balancer and copy the DNS name e.g.
   ![image](https://user-images.githubusercontent.com/7879884/151684310-2261c688-5587-4152-8b82-0e52e07a90c6.png)
     
   Or   
     
   in the Deploy Terraform stage of the deploy workflow output (scroll to bottom)
   ![image](https://user-images.githubusercontent.com/7879884/151894557-7e46e9c0-f052-417a-bfbe-36e3ea6cebae.png)


3. Call the Application  
   The easiest way to test is by using the curl command or you can use your favourite rest client.  
   An example using the curl command e.g.
   ```
   curl -i http://ben-tech-challenge-local-alb-1804404778.ap-southeast-2.elb.amazonaws.com/health
   ```
   ![image](https://user-images.githubusercontent.com/7879884/151684387-a3dec703-d8d8-4467-8878-8eae798abcba.png)

  
**Clean Up**  
```
# From the terraform directory
make destroy
```
  
## Improvements
This is by no means a production ready design; I would recommend that the following improvements be made to make it a more complete solution  
- Logging and Metrics Configuration
- Resource Tagging
- Replace GitHub Secrets with a Centralized Parameter/Secrets Store
- TLS on the ALB and Container
- API Auth
- API Error Handling
- Deploy The Container Service on a Private Subnet with a Nat Gateway for Outbound Internet Access
- Add unit testing of the application to the CI/CD Pipeline
- Add Linting of the Terraform templates to the CI/CD Pipeline
- For team environments; Set up a branching strategy including peer review/approval required for merges to main
- Modularise Terraform Components for Re-Usability
