with source as (

    select * from {{ source('snapchat_ads', 'adgroups') }}

),

latest_version as (

    select *
    from source
    qualify row_number() over (
        partition by ad_group_id
        order by ad_group_updated_at desc
    ) = 1

),

renamed as (

    select
        cast(ad_group_id as string)   as ad_group_id,
        cast(campaign_id as string)   as campaign_id,
        ad_group_name,
        ad_group_updated_at
    from latest_version

)

select * from renamed