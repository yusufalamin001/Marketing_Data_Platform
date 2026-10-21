{% macro generate_schema_name(custom_schema_name=none, node=none) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name in ['staging', 'production'] -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}