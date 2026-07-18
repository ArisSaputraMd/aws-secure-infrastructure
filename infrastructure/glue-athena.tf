resource "aws_glue_catalog_database" "security_analytics" {
  name = "${var.project_name}-${var.environment}-security_analytics"
}

# Athena query results go to dedicated own bucket and encrypted with SSE-S3
resource "aws_athena_workgroup" "security_analytics" {
  name = "${var.project_name}-${var.environment}-security-analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_output.id}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}


# CloudTrail Management Events catalog
resource "aws_glue_catalog_table" "cloudtrail_management_events" {
  name          = "${var.project_name}-${var.environment}-cloudtrail_management_events"
  database_name = aws_glue_catalog_database.security_analytics.name
  table_type    = "EXTERNAL_TABLE"

  partition_keys {
    name = "timestamp"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.security_logs.id}/cloudtrail/management-events/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/${data.aws_region.current.region}"
    input_format  = "com.amazon.emr.cloudtrail.CloudTrailInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "cloudtrail-serde"
      serialization_library = "org.apache.hive.hcatalog.data.JsonSerDe"
    }

    columns {
      name = "eventversion"
      type = "string"
    }
    columns {
      name = "useridentity"
      type = "struct<type:string,principalid:string,arn:string,accountid:string,invokedby:string,accesskeyid:string,username:string,onbehalfof:struct<userid:string,identitystorearn:string>,sessioncontext:struct<attributes:struct<mfaauthenticated:string,creationdate:string>,sessionissuer:struct<type:string,principalid:string,arn:string,accountid:string,username:string>,ec2roledelivery:string,webidfederationdata:struct<federatedprovider:string,attributes:map<string,string>>>>"
    }
    columns {
      name = "eventtime"
      type = "string"
    }
    columns {
      name = "eventsource"
      type = "string"
    }
    columns {
      name = "eventname"
      type = "string"
    }
    columns {
      name = "awsregion"
      type = "string"
    }
    columns {
      name = "sourceipaddress"
      type = "string"
    }
    columns {
      name = "useragent"
      type = "string"
    }
    columns {
      name = "errorcode"
      type = "string"
    }
    columns {
      name = "errormessage"
      type = "string"
    }
    columns {
      name = "requestparameters"
      type = "string"
    }
    columns {
      name = "responseelements"
      type = "string"
    }
    columns {
      name = "additionaleventdata"
      type = "string"
    }
    columns {
      name = "requestid"
      type = "string"
    }
    columns {
      name = "eventid"
      type = "string"
    }
    columns {
      name = "readonly"
      type = "string"
    }
    columns {
      name = "resources"
      type = "array<struct<arn:string,accountid:string,type:string>>"
    }
    columns {
      name = "eventtype"
      type = "string"
    }
    columns {
      name = "apiversion"
      type = "string"
    }
    columns {
      name = "recipientaccountid"
      type = "string"
    }
    columns {
      name = "serviceeventdetails"
      type = "string"
    }
    columns {
      name = "sharedeventid"
      type = "string"
    }
    columns {
      name = "vpcendpointid"
      type = "string"
    }
    columns {
      name = "vpcendpointaccountid"
      type = "string"
    }
    columns {
      name = "eventcategory"
      type = "string"
    }
    columns {
      name = "addendum"
      type = "struct<reason:string,updatedfields:string,originalrequestid:string,originaleventid:string>"
    }
    columns {
      name = "sessioncredentialfromconsole"
      type = "string"
    }
    columns {
      name = "edgedevicedetails"
      type = "string"
    }
    columns {
      name = "tlsdetails"
      type = "struct<tlsversion:string,ciphersuite:string,clientprovidedhostheader:string>"
    }
  }

  parameters = {
    EXTERNAL                             = "TRUE"
    "projection.enabled"                 = "true"
    "projection.timestamp.type"          = "date"
    "projection.timestamp.format"        = "yyyy/MM/dd"
    "projection.timestamp.interval"      = "1"
    "projection.timestamp.interval.unit" = "DAYS"
    # Replace the date with the actual date your management-events trail started delivering
    "projection.timestamp.range" = "2026/07/01,NOW"
    "storage.location.template"  = "s3://${aws_s3_bucket.security_logs.id}/cloudtrail/management-events/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/${data.aws_region.current.region}/$${timestamp}"
  }
}

##############################################
# CloudTrail - Data Events (S3 / mattermost-files)
# Identical schema to management events - same CloudTrail JSON envelope,
# only the S3 location and event content differ.
##############################################

resource "aws_glue_catalog_table" "cloudtrail_data_events" {
  name          = "cloudtrail_data_events"
  database_name = aws_glue_catalog_database.security_analytics.name
  table_type    = "EXTERNAL_TABLE"

  partition_keys {
    name = "timestamp"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.security_logs.id}/cloudtrail/data-events/mattermost-files/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/${data.aws_region.current.region}"
    input_format  = "com.amazon.emr.cloudtrail.CloudTrailInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "cloudtrail-serde"
      serialization_library = "org.apache.hive.hcatalog.data.JsonSerDe"
    }

    columns {
      name = "eventversion"
      type = "string"
    }
    columns {
      name = "useridentity"
      type = "struct<type:string,principalid:string,arn:string,accountid:string,invokedby:string,accesskeyid:string,username:string,onbehalfof:struct<userid:string,identitystorearn:string>,sessioncontext:struct<attributes:struct<mfaauthenticated:string,creationdate:string>,sessionissuer:struct<type:string,principalid:string,arn:string,accountid:string,username:string>,ec2roledelivery:string,webidfederationdata:struct<federatedprovider:string,attributes:map<string,string>>>>"
    }
    columns {
      name = "eventtime"
      type = "string"
    }
    columns {
      name = "eventsource"
      type = "string"
    }
    columns {
      name = "eventname"
      type = "string"
    }
    columns {
      name = "awsregion"
      type = "string"
    }
    columns {
      name = "sourceipaddress"
      type = "string"
    }
    columns {
      name = "useragent"
      type = "string"
    }
    columns {
      name = "errorcode"
      type = "string"
    }
    columns {
      name = "errormessage"
      type = "string"
    }
    columns {
      name = "requestparameters"
      type = "string"
    }
    columns {
      name = "responseelements"
      type = "string"
    }
    columns {
      name = "additionaleventdata"
      type = "string"
    }
    columns {
      name = "requestid"
      type = "string"
    }
    columns {
      name = "eventid"
      type = "string"
    }
    columns {
      name = "readonly"
      type = "string"
    }
    columns {
      name = "resources"
      type = "array<struct<arn:string,accountid:string,type:string>>"
    }
    columns {
      name = "eventtype"
      type = "string"
    }
    columns {
      name = "apiversion"
      type = "string"
    }
    columns {
      name = "recipientaccountid"
      type = "string"
    }
    columns {
      name = "serviceeventdetails"
      type = "string"
    }
    columns {
      name = "sharedeventid"
      type = "string"
    }
    columns {
      name = "vpcendpointid"
      type = "string"
    }
    columns {
      name = "vpcendpointaccountid"
      type = "string"
    }
    columns {
      name = "eventcategory"
      type = "string"
    }
    columns {
      name = "addendum"
      type = "struct<reason:string,updatedfields:string,originalrequestid:string,originaleventid:string>"
    }
    columns {
      name = "sessioncredentialfromconsole"
      type = "string"
    }
    columns {
      name = "edgedevicedetails"
      type = "string"
    }
    columns {
      name = "tlsdetails"
      type = "struct<tlsversion:string,ciphersuite:string,clientprovidedhostheader:string>"
    }
  }

  parameters = {
    EXTERNAL                             = "TRUE"
    "projection.enabled"                 = "true"
    "projection.timestamp.type"          = "date"
    "projection.timestamp.format"        = "yyyy/MM/dd"
    "projection.timestamp.interval"      = "1"
    "projection.timestamp.interval.unit" = "DAYS"
    # Replace the date with the actual date your data-events trail started delivering
    "projection.timestamp.range" = "2026/07/01,NOW"
    "storage.location.template"  = "s3://${aws_s3_bucket.security_logs.id}/cloudtrail/data-events/mattermost-files/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/${data.aws_region.current.region}/$${timestamp}"
  }
}

# VPC Flow Logs - ALL traffic, Parquet, per-hour partition
# ==============================================================================
# *** NOTE ***
# Column list/order below is a custom EXTENDED field set. If your aws_flow_log.log_format string uses a different 
# field list or order, this WILL silently misalign columns. Parquet has no header row to self-correct.
# ==============================================================================

resource "aws_glue_catalog_table" "vpc_flow_logs" {
  name          = "vpc_flow_logs"
  database_name = aws_glue_catalog_database.security_analytics.name
  table_type    = "EXTERNAL_TABLE"

  partition_keys {
    name = "aws_account_id"
    type = "string"
  }
  partition_keys {
    name = "aws_region"
    type = "string"
  }
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.security_logs.id}/flow-logs/AWSLogs/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    # Standard AWS flow log fields (VERIFY against your actual log_format)
    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "int"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start"
      type = "bigint"
    }
    columns {
      name = "end"
      type = "bigint"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }

    # Etended for security investigation
    columns {
      name = "vpc_id"
      type = "string"
    }
    columns {
      name = "subnet_id"
      type = "string"
    }
    columns {
      name = "instance_id"
      type = "string"
    }
    columns {
      name = "tcp_flags"
      type = "int"
    }
    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "pkt_srcaddr"
      type = "string"
    }
    columns {
      name = "pkt_dstaddr"
      type = "string"
    }
    columns {
      name = "flow_direction"
      type = "string"
    }
    columns {
      name = "traffic_path"
      type = "int"
    }
  }

  parameters = {
    EXTERNAL                           = "TRUE"
    "projection.enabled"               = "true"
    "projection.aws_account_id.type"   = "enum"
    "projection.aws_account_id.values" = data.aws_caller_identity.current.account_id
    "projection.aws_region.type"       = "enum"
    "projection.aws_region.values"     = data.aws_region.current.region
    "projection.year.type"             = "integer"
    "projection.year.range"            = "2026,2036"
    "projection.month.type"            = "integer"
    "projection.month.range"           = "01,12"
    "projection.month.digits"          = "2"
    "projection.day.type"              = "integer"
    "projection.day.range"             = "01,31"
    "projection.day.digits"            = "2"
    "projection.hour.type"             = "integer"
    "projection.hour.range"            = "00,23"
    "projection.hour.digits"           = "2"
    "storage.location.template"        = "s3://${aws_s3_bucket.security_logs.id}/flow-logs/AWSLogs/aws-account-id=$${aws-account-id}/aws-service=vpcflowlogs/aws-region=$${aws-region}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}"
  }
}

# ALB Access Logs catalog
# Schema + regex per AWS's own current documentation (RegexSerDe)
resource "aws_glue_catalog_table" "alb_access_logs" {
  name          = "alb_access_logs"
  database_name = aws_glue_catalog_database.security_analytics.name
  table_type    = "EXTERNAL_TABLE"

  partition_keys {
    name = "day"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.elb_logs.id}/elb/alb-accesslogs/AWSLogs/${data.aws_caller_identity.current.account_id}/elasticloadbalancing/${data.aws_region.current.region}"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "alb-regex-serde"
      serialization_library = "org.apache.hadoop.hive.serde2.RegexSerDe"
      parameters = {
        "serialization.format" = "1"
        "input.regex"          = "([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*):([0-9]*) ([^ ]*)[:-]([0-9]*) ([-.0-9]*) ([-.0-9]*) ([-.0-9]*) (|[-0-9]*) (-|[-0-9]*) ([-0-9]*) ([-0-9]*) \"([^ ]*) (.*) (- |[^ ]*)\" \"([^\"]*)\" ([A-Z0-9-_]+) ([A-Za-z0-9.-]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^\"]*)\" ([-.0-9]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^ ]*)\" \"([^\\s]+?)\" \"([^\\s]+)\" \"([^ ]*)\" \"([^ ]*)\" ?([^ ]*)? ?( .*)?"
      }
    }

    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "time"
      type = "string"
    }
    columns {
      name = "elb"
      type = "string"
    }
    columns {
      name = "client_ip"
      type = "string"
    }
    columns {
      name = "client_port"
      type = "int"
    }
    columns {
      name = "target_ip"
      type = "string"
    }
    columns {
      name = "target_port"
      type = "int"
    }
    columns {
      name = "request_processing_time"
      type = "double"
    }
    columns {
      name = "target_processing_time"
      type = "double"
    }
    columns {
      name = "response_processing_time"
      type = "double"
    }
    columns {
      name = "elb_status_code"
      type = "int"
    }
    columns {
      name = "target_status_code"
      type = "string"
    }
    columns {
      name = "received_bytes"
      type = "bigint"
    }
    columns {
      name = "sent_bytes"
      type = "bigint"
    }
    columns {
      name = "request_verb"
      type = "string"
    }
    columns {
      name = "request_url"
      type = "string"
    }
    columns {
      name = "request_proto"
      type = "string"
    }
    columns {
      name = "user_agent"
      type = "string"
    }
    columns {
      name = "ssl_cipher"
      type = "string"
    }
    columns {
      name = "ssl_protocol"
      type = "string"
    }
    columns {
      name = "target_group_arn"
      type = "string"
    }
    columns {
      name = "trace_id"
      type = "string"
    }
    columns {
      name = "domain_name"
      type = "string"
    }
    columns {
      name = "chosen_cert_arn"
      type = "string"
    }
    columns {
      name = "matched_rule_priority"
      type = "string"
    }
    columns {
      name = "request_creation_time"
      type = "string"
    }
    columns {
      name = "actions_executed"
      type = "string"
    }
    columns {
      name = "redirect_url"
      type = "string"
    }
    columns {
      name = "lambda_error_reason"
      type = "string"
    }
    columns {
      name = "target_port_list"
      type = "string"
    }
    columns {
      name = "target_status_code_list"
      type = "string"
    }
    columns {
      name = "classification"
      type = "string"
    }
    columns {
      name = "classification_reason"
      type = "string"
    }
    columns {
      name = "conn_trace_id"
      type = "string"
    }
  }

  parameters = {
    EXTERNAL                       = "TRUE"
    "projection.enabled"           = "true"
    "projection.day.type"          = "date"
    "projection.day.format"        = "yyyy/MM/dd"
    "projection.day.interval"      = "1"
    "projection.day.interval.unit" = "DAYS"
    # change date with your actual start date
    "projection.day.range"      = "2026/07/01,NOW"
    "storage.location.template" = "s3://${aws_s3_bucket.elb_logs.id}/elb/alb-accesslogs/AWSLogs/${data.aws_caller_identity.current.account_id}/elasticloadbalancing/${data.aws_region.current.region}/$${day}"
  }
}
