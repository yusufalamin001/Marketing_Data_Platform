with source as (

    select * from {{ source('snapchat_ads', 'ads_stats') }}

),

renamed as (

    select
        cast(ad_detail_id as string)          as ad_id,
        cast(ad_date as date)                 as report_date,
        upper(ad_country)                     as country_code,
        upper(ad_currency_code)               as currency_code,
        cast(ad_spend as decimal(18, 6))      as spend,
        cast(ad_impressions as bigint)        as impressions,
        cast(cast(nullif(trim(ad_clicks), 'null') as decimal(18, 0)) as bigint) as clicks
    from source

)

select * from renamed