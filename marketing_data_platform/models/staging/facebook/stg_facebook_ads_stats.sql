with source as (

    select * from {{ source('facebook_ads', 'ads_stats') }}

),

renamed as (

    select
        cast(ad_id as string)                as ad_id,
        cast(account_id as string)           as account_id,
        cast(ad_date as date)                as report_date,
        cast(ad_spend as decimal(18, 2))     as spend,
        cast(cast(nullif(trim(ad_impressions), 'null') as decimal(18, 0)) as bigint) as impressions,
        cast(cast(nullif(trim(ad_clicks), 'null') as decimal(18, 0)) as bigint)      as clicks
    from source

)

select * from renamed