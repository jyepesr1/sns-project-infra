Terraform code
==============

Deploying a SNS Email notification project using ECS Fargate.
-------------------------------------------------------------

Considerations
--------------
* When the SNS topic is created you have to manually registry the subscription of email type, because is not supported by Terraform currently.

* The Terraform output is the ECR url which is needed in the CI/CD pipeline for the code, please set the variable AWS_ECR_ACCOUNT_URL with this output.

  Note: Just copy the URL without the repo name.

* Run the CI/CD Pipeline in the code repo, if not ECS will not be able to pull the images from the ECR.

* If you want to run in a different port that 80, you can change the variable app_port
