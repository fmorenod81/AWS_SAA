# AWS_SAA

AWS Certified Solutions Architect – Associate (SAA-C03)

Actualizacion 08-08-2024

fmorenod@gmail.com - http://www.fmorenod.co

- [AWS\_SAA](#aws_saa)
  - [Repo sections](#repo-sections)
  - [Timetable](#timetable)
  - [Challenges and assignment](#challenges-and-assignment)
  - [External Links](#external-links)

## Repo sections

This repo is divided on:

- **[Code](Code/README.md):** Labs code using CLI (Windows, mainly), IaC( TF) and Clou dFormation (CFmt).
- **[Presentations](Presentations/README.md):** Powerpoint Presentation on PDF

## Timetable

| DESCRIPTION  |xxh|  DATE    |        TOPIC/LAB                               | CLI/IaC  |
|--------------|---|----------|------------------------------------------------|----------|
|  Class 00 /2h|02h|18-07-2024| Personal ideas for self-study                  |          |
|  Class 01 /2h|04h|18-07-2024| Cloud and AWS Exploration. Method, Schedule    |          |
|  Lab   01 /1h|05h|18-07-2024| Budget creation and admin user/CLI config      | CLI/TF   |
|  Class 02 /2h|07h|19-07-2024| Identity: IAM y Org, AD, SSO and  Cognito      |          |
|  Lab   02 /1h|08h|19-07-2024| Developer user and role management             | CLI/TF   |
|  Class 03 /2h|10h|22-07-2024| S3 and Big Data                                |          |
|  Lab   03 /1h|11h|22-07-2024| Static hosting on S3 and replication           | CLI/TF   |
|  Class 04 /2h|13h|24-07-2024| VPC, ENI and ENA/EFA                           |          |
|  Class 05 /2h|15h|26-07-2024| EC2 and Container Services                     |          |
|  Lab   04a/1h|16h|26-07-2024| VPC and related svcs, SSH access between subnet| CLI/TF   |
|  Lab   04b/1h|23h|05-08-2024| VPC and related svcs, SSH access and VPC Endpoi| CLI/TF*1 |
|  Class 06 /2h|18h|29-07-2024| ELB, EC2 AutoScaling, CWatch and Defense tools |          |
|  Lab   05a/1h|24h|05-08-2024| ENI, EIP and Docker on an instance             | CLI/TF   |
|  Lab   05b/1h|25h|05-08-2024| ALB and port/path routing                      | CLI/TF*2 |
|  Lab   06a/2h|27h|08-08-2024| ALB, NLB; VPC Peering on a layered arch        | CLI/CFmt |
|  Lab   06b/1h|28h|08-08-2024| ALB, NLB; VPC Peering; layered arch; EC2 AutoSc| CLI*3    |
|  Class 07 /2h|22h|02-08-2024| Terraform for AWS                              |          |
|  Class 08 /2h|20h|31-07-2024| DB: RDS and Aurora; Cloudformation             |          |
|  Lab   07 /3h|31h|12-08-2024| MySQL RDS and previous IaC Labs                |CLI/CFmt*4|
|  Class 09 /2h|33h|14-08-2024| Serverless: DynamoDB and Lambda                |          |
|  Lab   08 /1h|34h|14-08-2024| DynamoDB Streams, Lambda and SNS               | CLI      |
|  Class 10 /2h|36h|20-08-2024| EBS/EFS and Migration Tools                    |          |
|  Lab   09 /1h|37h|20-08-2024| Multiattach EBS y hot resize                   | CLI*5    |
|  Class 11 /2h|39h|23-08-2024| Route 53, CloudFront, ACM. Auditing Services   |          |
|  Lab   10 /1h|40h|23-08-2024| Route 53 Policy and Digital Certificates       | CLI      |
|  Class 12 /2h|42h|26-08-2024| Enterprise Landing Zone: Multicloud & Example  |          |
|  Lab   11 / h|00h|26-08-2024|[Creating your first API from scratch with OpenA](https://catalog.us-east-1.prod.workshops.aws/workshops/4ff2d034-dee1-4570-93d9-11a54cc5d60c/en-US)|          |

|  Exam     /2h|44h|28-08-2024| Practice Exam for AWS SAA-C03                  |          |
|--------------|---|----------|------------------------------------------------|----------|

TF   = Hashicorp Terraform

CFmt = AWS Cloudformation

## Challenges and assignment

(*1)Reto Labs4b - En terraform, crear el VPC Peering y luego, el VPC Endpoint en modo gateway para ir a S3.

(*2)Reto Labs5b - En terraform, hacer el routing por el path.

(*3)Reto Labs6b - En CLI, realizar la actualizacion de Launch Configuration a Launch Template y actualizar el CFmt de Labs6a a Labs6b

(*4)Reto Labs7 - Realizar un script para que al ejecutar el RDS se cree el esquema de manera automatica. Averiguar las limitaciones u opciones de CFmt para realizar esto.

(*5)Reto Labs9 - Realizarlo en Terraform o en Cloudformation como desee.

## External Links

Cloud Definition - NIST Definition - NOTE: Service Models and Deployment Models - Link: [Official NIST Page](https://ccsp.alukos.com/standards/nist-sp-800-145/)

AWS Products - NOTE: Amazon RDS for DB2 - Link: [AWS Page](https://aws.amazon.com/products/?aws-products-all.sort-by=item.additionalFields.productNameLowercase&aws-products-all.sort-order=asc&awsf.re%3AInvent=event-year%23aws-reinvent-2023&awsf.Free%20Tier%20Type=*all&awsf.tech-category=*all)

Example to use roles on IAM - Link: [AWS Repost](https://repost.aws/knowledge-center/iam-assume-role-cli)

Budget Tutorial - Link: [AWS Tutorial](https://www.youtube.com/watch?v=O0sofGVT7uw)

Bootstrapping Options - Link: [Example](https://s3.amazonaws.com/cloudformation-examples/BoostrappingApplicationsWithAWSCloudFormation.pdf)

Instance Naming Convention - Link: [Official Doc](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html)

Instance Explorer - Link: [Official Page](https://aws.amazon.com/ec2/instance-explorer/)

AWS Calculator, case on EC2 - Link: [Official Page](https://calculator.aws/#/addService/ec2-enhancement)

Amazon EC2 Reserved Instances and Other AWS Reservation Models - Link: [Savings Plans](https://docs.aws.amazon.com/whitepapers/latest/cost-optimization-reservation-models/savings-plans.html) and [Reserved Instances](https://docs.aws.amazon.com/whitepapers/latest/cost-optimization-reservation-models/introduction.html)

How to explain spot instances for Dummies - Link [No-Official Video](https://youtu.be/mgWZls55ATs?t=17)

VPC - All VPC Elements/Components - Link: [Official Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)

ACL - Mejor grafica - Link [Official Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)

Sec Groups - Ejemplo - Link [Official Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html)

Transit Gateways Scenarios - Link: [AWS Docs](https://docs.aws.amazon.com/vpc/latest/tgw/TGW_Scenarios.html)

Looks Intelligent Tier - S3 Pricing - Link: [Official Pricing Page](https://aws.amazon.com/s3/pricing/)

How control access to S3: IAM Policies, S3 Policies and ACLs - Link: [Official Blog](https://aws.amazon.com/blogs/security/iam-policies-and-bucket-policies-and-acls-oh-my-controlling-access-to-s3-resources/)


Data 101: Data Classification & Storage - Link: [AWS Community](https://community.aws/posts/data-classification-and-storage)

RDS Web Page - Link: [Official Page](https://aws.amazon.com/relational-database/)

DB differences on Writable RR, backup or parallel replication on Read Replication - Link: [Official Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html#USER_ReadRepl.Overview.Differences)

Multi-AZ DB instance deployments - Link: [Official Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html)

MultiAZ DB Cluster - !Readable! MultiAZ Deploy - Link: [Official Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html)

Codecommit depreceated ? - Link: [Official News](https://aws.amazon.com/blogs/devops/how-to-migrate-your-aws-codecommit-repository-to-another-git-provider/)

Codestar depreceated ? - Link: [Official Page](https://aws.amazon.com/codestar/faqs/)

MultiAZ or Multiregion - Link: [Blog](https://www.flashgrid.io/news/multi-az-vs-multi-region-in-the-cloud/?utm_source=linkedin&utm_campaign=Sponsored%20Post&utm_medium=cpc&utm_content=Multi-AZ%20vs%20Multi-Region/)

DynamoDB - Improving data access with secondary indexes - Link: [Official Doc](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html#:~:text=A%20global%20secondary%20index%20lets,key%20value%20in%20the%20query.&text=Queries%20on%20global%20secondary%20indexes%20support%20eventual%20consistency%20only.)

Amazon DynamoDB Transactions: How it works - Link: [Official Doc](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html)

---
Francisco Moreno Diaz -  `fmorenod@gmail.com`
