# VALUES IN .TFVARS FILE

####PROVIDER####

variable region {
    type = string 
}

variable access_key {
    type = string 
}

variable secret_key {
    type = string 
}


####DATABASE####

variable db_name {
    type = string 
}
variable username {
    type = string 
}
variable password {
    type = string 
}
variable port {
    type = number 
}
variable engine {
    type = string 
}
