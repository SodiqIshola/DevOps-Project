
# --- VPC CONFIGURATION ---

# Create the isolated network environment for your infrastructure
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # The primary IP range for the entire VPC (defined in your variables)
  enable_dns_hostnames = true         # Provides AWS-assigned DNS hostnames to instances (required for some AWS services)
  enable_dns_support   = true         # Enables the internal AWS DNS resolver for the VPC
  tags = { Name = "fargate-vpc" }     # Metadata tag to name the VPC in the AWS Console
}

# --- PUBLIC SUBNETS ---

# Create Public Subnets across 2 Availability Zones for the Load Balancer
resource "aws_subnet" "public" {
  count                   = 2 # Creates two separate subnets for High Availability (redundancy)
  vpc_id                  = aws_vpc.main.id # References the ID of the VPC created above
  # Splits the VPC CIDR into smaller /24 blocks (e.g., 10.0.0.0/24 and 10.0.1.0/24)
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) 

  # Assigns each subnet to a different physical Availability Zone
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  # Automatically assigns a public IP to resources launched here (required for Fargate public tasks)
  map_public_ip_on_launch = true 

  tags = { Name = "fargate-public-${count.index}" } # Names the subnets public-0 and public-1
}

# --- PRIVATE SUBNETS ---

# Create Private Subnets where the actual Node.js application will live
resource "aws_subnet" "private" {
  count             = 2 # Creates two subnets to allow Fargate tasks to failover if one AZ goes down
  vpc_id            = aws_vpc.main.id # References the ID of the VPC created above
  # Offsets the index by +2 to avoid IP overlap with the public subnets (e.g., 10.0.2.0/24)
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2) 
  # Matches the Availability Zones used by the public subnets for consistency
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "fargate-private-${count.index}" } # Names the subnets private-0 and private-1
}


# --- INTERNET CONNECTIVITY ---

# Internet Gateway: Acts as the "door" allowing traffic between the VPC and the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id             # Links the IGW to your VPC so traffic has a path out
}

# Create a static Elastic IP address for the NAT Gateway to use
resource "aws_eip" "nat" {
  domain = "vpc" # Allocates a persistent public IP address specifically for VPC use
}

# NAT Gateway allows private tasks to reach the internet (to pull Docker images) without being exposed to it
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id           # Assigns the Elastic IP created above to the NAT Gateway
  subnet_id     = aws_subnet.public[0].id   # The NAT MUST sit in a Public subnet to access the IGW
  depends_on    = [aws_internet_gateway.igw] # Prevents creation errors by waiting for the IGW to be ready
}


# --- PUBLIC ROUTING ---

# Route table defining how traffic leaves the Public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id # Attaches the table to the VPC

  route {
    cidr_block = "0.0.0.0/0"                 # Rule for all destination traffic (the internet)
    gateway_id = aws_internet_gateway.igw.id # Sends that traffic through the Internet Gateway
  }

  tags = { Name = "fargate-public-rt" } # Identifies this as the public routing table
}

# Connect the Public Subnets to the Public Route Table
resource "aws_route_table_association" "public" {
  count          = 2                                  # Applies to both public subnets
  subnet_id      = aws_subnet.public[count.index].id  # Maps each subnet ID
  route_table_id = aws_route_table.public.id          # Points them to the IGW route
}



# --- PRIVATE ROUTING ---

# Route table defining how traffic leaves the Private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id # Attaches the table to the VPC

  route {
    cidr_block     = "0.0.0.0/0"             # Rule for all destination traffic (the internet)
    nat_gateway_id = aws_nat_gateway.main.id # Sends internet-bound traffic through the NAT Gateway
  }

  tags = { Name = "fargate-private-rt" } # Identifies this as the private routing table
}

# Connect the Private Subnets to the Private Route Table
resource "aws_route_table_association" "private" {
  count          = 2                                   # Applies to both private subnets
  subnet_id      = aws_subnet.private[count.index].id  # Maps each subnet ID
  route_table_id = aws_route_table.private.id          # Points them to the NAT Gateway route
}













