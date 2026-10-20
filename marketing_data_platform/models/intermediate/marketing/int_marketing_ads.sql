select * from {{ ref('int_facebook_ads_enriched') }}

union all

select * from {{ ref('int_snapchat_ads_enriched') }}