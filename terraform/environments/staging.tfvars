aws_region         = "ap-south-1"
environment        = "staging"
instance_type      = "t3.micro"
application_cidrs  = []
log_retention_days = 7
# initial_image is supplied through TF_VAR_initial_image after the image is published.
