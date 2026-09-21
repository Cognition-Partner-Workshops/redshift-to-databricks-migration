CREATE SCHEMA IF NOT EXISTS lake.core
WITH (location = 'file:///data/warehouse/core');

CREATE SCHEMA IF NOT EXISTS lake.mart
WITH (location = 'file:///data/warehouse/mart');
