#!/bin/bash

################
# Description:
# - Verify if user has AWS Installed, User might be using Windows, Linux or mac
# - Verify if user has configured AWS CLI with proper credentials
# - Script should accept one parameter to create or teardown VPC and Subnet if they exist
# - if running the script with "create" parameter, it should create VPC and Subnet
# - if running the script with "teardown" parameter, it should delete the created VPC and Subnet
# - if no parameter is passed, it should print usage instructions
# - Script should handle errors gracefully and provide meaningful messages to the user
################

# variables
VPC_CIDR="10.0.0.0/16"         # CIDR block for the VPC
SUBNET_CIDR="10.0.1.0/24"      # CIDR block for the public subnet
REGION="us-east-1"             # AWS region to create resources in
VPC_NAME="demo-vpc"            # Name tag for the VPC
SUBNET_NAME="demo-public-subnet" # Name tag for the public subnet
SUBNET_AZ="us-east-1a"         # Availability Zone for the subnet
# Check if AWS CLI is installed
AWS_CLI=$(command -v aws)
if [ -z "$AWS_CLI" ]; then
  echo "AWS CLI is not installed. Please install it first."
  exit 1
fi
# Check if AWS CLI is configured
aws sts get-caller-identity > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "AWS CLI is not configured. Please configure it with valid credentials."
    exit 1
fi

# Check script parameters
ACTION=$1

if [ "$ACTION" == "create" ]; then
    # Create VPC
    VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query 'Vpc.VpcId' --output text)
    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        echo "Failed to create VPC. Exiting."
        exit 1
    fi
    SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR --region $REGION --query 'Subnet.SubnetId' --output text)
    if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" == "None" ]; then
        echo "Failed to create Public Subnet."
        # Optionally clean up VPC if subnet creation failed
        aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
        exit 1
    fi
    echo "Created Public Subnet with ID: $SUBNET_ID"
    # Tag the VPC and Subnet
    aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME --region $REGION
    if [ $? -ne 0 ]; then
        echo "Failed to tag VPC with Name: $VPC_NAME"
    fi
    aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=$SUBNET_NAME --region $REGION
    if [ $? -ne 0 ]; then
        echo "Failed to tag Subnet with Name: $SUBNET_NAME"
    fi
    echo "Tagged VPC and Subnet"
    echo "VPC '$VPC_NAME' and Public Subnet '$SUBNET_NAME' creation completed."
elif [ "$ACTION" == "teardown" ]; then
    # Teardown VPC and Subnet
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --region $REGION --query 'Vpcs[0].VpcId' --output text)
    SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_NAME" --region $REGION --query 'Subnets[0].SubnetId' --output text)
    if [[ -n "$SUBNET_ID" && "$SUBNET_ID" == subnet-* ]]; then
        aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION
        echo "Deleted Subnet with ID: $SUBNET_ID"
    else
        echo "Subnet '$SUBNET_NAME' not found."
    fi
    if [[ -n "$VPC_ID" && "$VPC_ID" == vpc-* ]]; then
        aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
        echo "Deleted VPC with ID: $VPC_ID"
    else
        echo "VPC '$VPC_NAME' not found."
    fi
    echo "Teardown completed."
else
    echo "Usage: $0 [create|teardown]"
    echo "  create   - Create VPC and Subnet"
    echo "  teardown - Delete VPC and Subnet"
    exit 1
fi

# The usage instructions and error handling for create/teardown actions have been consolidated above.
# For details on previous logic, refer to commit <commit-hash> or project history.
  echo "  create   - Create VPC and Subnet"
  echo "  teardown - Delete VPC and Subnet"
  exit 1
