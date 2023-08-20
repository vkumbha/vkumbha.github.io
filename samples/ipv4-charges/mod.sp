mod "local" {
  title = "Public IP insights"
}

dashboard "public_ips" {
  title = "Public IP insights"

  card {
    sql   = query.total_public_ips.sql
    width = 4
  }

  card {
    type  = "info"
    icon  = "currency-dollar"
    sql   = query.current_costs.sql
    width = 4
  }

  card {
    type  = "info"
    icon  = "currency-dollar"
    sql   = query.expected_costs.sql
    width = 4
  }

  chart {
    title = "Public IP types"
    sql   = query.public_ip_types.sql
    type  = "donut"
    width = 6
  }

  chart {
    title = "EIP Usage"
    sql   = query.eip_usage.sql
    type  = "donut"
    width = 6

    series "count" {
      point "associated" {
        color = "ok"
      }
      point "unassociated" {
        color = "alert"
      }
    }
  }

  chart {
    title = "Interface Types"
    sql   = query.interface_types.sql
    type  = "donut"
    width = 6
  }

  chart {
    title = "Service Managed Types"
    sql   = query.service_managed_types.sql
    type  = "donut"
    width = 6
  }

  chart {
    title = "Public IPs by Account"
    sql   = query.public_ips_by_account.sql
    type  = "column"
    width = 6
  }

  chart {
    title = "Public IPs by Region"
    sql   = query.public_ips_by_region.sql
    type  = "column"
    width = 6
  }

  table {
    sql = query.aws_public_ip_addresses.sql
  }
}

query "total_public_ips" {
  sql = <<-EOQ
with
  all_eips as (
    select
      association_public_ip as public_ip,
      region,
      account_id
    from
      aws_ec2_network_interface
    where
      association_public_ip is not null
      and association_allocation_id is null
    UNION ALL
    select
      public_ip,
      region,
      account_id
    from
      aws_vpc_eip
  )
select count(public_ip) as "Total Public IPs" from all_eips
EOQ
}

query "current_costs" {
  sql = <<-EOQ
with
  all_eips as (
    select
      association_public_ip as public_ip,
      region,
      account_id,
      case
        when attachment_status in ('detaching', 'detached') then 0.005
        when attachment_status in ('attaching', 'attached') then 0
      end as "current_price_per_hr",
      case
        when true then 0.005
      end as "new_price_per_hr"
    from
      aws_ec2_network_interface
    where
      association_public_ip is not null
      and association_allocation_id is null
    UNION ALL
    select
      public_ip,
      region,
      account_id,
      case
        when association_id is null then 0.005
        when association_id is not null then 0
      end as "current_price_per_hr",
      case
        when association_id is null then 0.005
        when association_id is not null then 0.005
      end as "new_price_per_hr"
    from
      aws_vpc_eip
  )
select sum("current_price_per_hr")*24*30::money as "Total Current Expense Per Month" from all_eips
EOQ
}

query "expected_costs" {
  sql = <<-EOQ
with
  all_eips as (
    select
      association_public_ip as public_ip,
      region,
      account_id,
      case
        when attachment_status in ('detaching', 'detached') then 0.005
        when attachment_status in ('attaching', 'attached') then 0
      end as "current_price_per_hr",
      case
        when true then 0.005
      end as "new_price_per_hr"
    from
      aws_ec2_network_interface
    where
      association_public_ip is not null
      and association_allocation_id is null
    UNION ALL
    select
      public_ip,
      region,
      account_id,
      case
        when association_id is null then 0.005
        when association_id is not null then 0
      end as "current_price_per_hr",
      case
        when association_id is null then 0.005
        when association_id is not null then 0.005
      end as "new_price_per_hr"
    from
      aws_vpc_eip
  )
select sum("new_price_per_hr")*24*30::money as "Total New Expense Per Month" from all_eips
EOQ
}

query "public_ip_types" {
  sql = <<-EOQ
with
  all_eips as (
    select
      association_public_ip as public_ip,
      case
        when attached_instance_id is not null then 'ec2-public-ip'
        when attached_instance_id is null then 'service-managed-ip'
      end as "address_type",
      region,
      account_id
    from
      aws_ec2_network_interface
    where
      association_public_ip is not null
      and association_allocation_id is null
    UNION ALL
    select
      public_ip,
      case
        when public_ipv4_pool = 'amazon' then 'amazon-owned-eip'
        else 'byoip'
      end as "address_type",
      region,
      account_id
    from
      aws_vpc_eip
  )
  select address_type,count(address_type) from all_eips group by address_type
EOQ
}

query "interface_types" {
  sql = <<-EOQ
with
  all_eips as (
    select
      association_public_ip as public_ip,
      interface_type,
      region,
      account_id
    from
      aws_ec2_network_interface
    where
      association_public_ip is not null
      and association_allocation_id is null
    UNION ALL
    select
      public_ip,
      case
        when network_interface_id is not null then (select interface_type from aws_ec2_network_interface
          where network_interface_id = aws_vpc_eip.network_interface_id)
        when network_interface_id is null then network_interface_id
      end as interface_type,
      region,
      account_id
    from
      aws_vpc_eip
  )
  select interface_type,count(interface_type) from all_eips where interface_type is not null group by interface_type
EOQ
}

query "eip_usage" {
  sql = <<-EOQ
select
  case
    when association_id is null then 'unassociated'
    when association_id is not null then 'associated'
  end as association,
  count(public_ip)
from
  aws_vpc_eip
group by
  association
EOQ 
}

query "public_ips_by_account" {
  sql = <<-EOQ
with
  all_aws_public_ip_addresses as (
    select
      association_public_ip as public_ip,
      region,
      account_id
    from
      aws_ec2_network_interface
    where
      association_public_ip is not null
      and association_allocation_id is null
    UNION ALL
    select
      public_ip,
      region,
      account_id
    from
      aws_vpc_eip
  )
select account_id, count(account_id) from all_aws_public_ip_addresses group by account_id order by count desc
EOQ
}

query "public_ips_by_region" {
  sql = <<-EOQ
with
  all_aws_public_ip_addresses as (
    select
      association_public_ip as public_ip,
      region,
      account_id
    from
      aws_ec2_network_interface
    where
      association_public_ip is not null
      and association_allocation_id is null
    UNION ALL
    select
      public_ip,
      region,
      account_id
    from
      aws_vpc_eip
  )
select region, count(region) from all_aws_public_ip_addresses group by region order by count desc
EOQ
}

query "aws_public_ip_addresses" {
  sql = <<-EOQ
select
  association_public_ip as public_ip,
  case
    when attachment_status in ('detaching', 'detached') then 'unassociated'
    when attachment_status in ('attaching', 'attached') then 'associated'
  end as association,
  case
    when attached_instance_id is not null then 'ec2-public-ip'
    when attached_instance_id is null then 'service-managed-ip'
  end as address_type,
  interface_type,
  network_interface_id,
  attached_instance_id as instance_id,
  region,
  account_id
from
  aws_ec2_network_interface
where
  association_public_ip is not null
  and association_allocation_id is null
UNION ALL
select
  public_ip,
  case
    when association_id is null then 'unassociated'
    when association_id is not null then 'associated'
  end as association,
  case
    when public_ipv4_pool = 'amazon' then 'amazon-owned-eip'
    else 'byoip'
  end as address_type,
  case
    when network_interface_id is not null then (select interface_type from aws_ec2_network_interface
      where network_interface_id = aws_vpc_eip.network_interface_id)
    when network_interface_id is null then network_interface_id
  end as interface_type,
  network_interface_id,
  instance_id,
  region,
  account_id
from
  aws_vpc_eip
order by
  association desc
EOQ
}

query "service_managed_types" {
  sql = <<-EOQ
select
  case
    when attached_instance_owner_id like 'amazon%' then attached_instance_owner_id
    else null
  end as attached_instance_owner_id,
  count(attached_instance_owner_id)
from
  aws_ec2_network_interface
where
  association_public_ip is not null
  and attached_instance_id is null
  and attached_instance_owner_id like 'amazon%'
group by
  attached_instance_owner_id
EOQ
}
