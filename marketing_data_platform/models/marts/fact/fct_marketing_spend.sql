{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='marketing_spend_key'
) }}

with source as (

    select * from {{ ref('int_marketing_ads') }}

),

{% if is_incremental() %}

watermark as (

    -- one cutoff per platform, because platforms load independently
    select
        platform,
        date_sub(max(report_date), {{ var('lookback_days', 3) }}) as reload_from
    from {{ this }}
    group by platform

),

{% endif %}

new_rows as (

    select source.*
    from source
    {% if is_incremental() %}
    left join watermark
        on source.platform = watermark.platform
    where watermark.reload_from is null
       or source.report_date >= watermark.reload_from
    {% endif %}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['platform', 'ad_id', 'report_date']) }} as marketing_spend_key,
        platform,
        report_date,
        account_id,
        currency_code,
        {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }}          as campaign_key,
        {{ dbt_utils.generate_surrogate_key(['platform', 'ad_id']) }}                as ad_key,
        spend,
        impressions,
        clicks,
        cast(clicks / nullif(impressions, 0) as decimal(18, 6))                      as ctr,
        cast(spend / nullif(clicks, 0) as decimal(18, 6))                            as cpc,
        cast(spend / nullif(impressions, 0) * 1000 as decimal(18, 6))                as cpm,
        current_timestamp()                                                          as dbt_updated_at
    from new_rows

)

select * from final