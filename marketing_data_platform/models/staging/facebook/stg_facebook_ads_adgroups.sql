with source as (

    select * from {{ source('facebook_ads', 'adgroups') }}

),

renamed as (

    select
        cast(ad_group_id as string)            as ad_group_id,
        ad_group_name,
        cast(ad_group_updated_at as timestamp) as ad_group_updated_at
    from source

)

select * from renamed