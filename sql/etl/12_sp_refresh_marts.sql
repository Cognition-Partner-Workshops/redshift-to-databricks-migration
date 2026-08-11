-- Stored procedure wrapper the customer's scheduler calls nightly.
CREATE OR REPLACE PROCEDURE mart.sp_refresh_marts()
AS $$
BEGIN
    RAISE INFO 'refresh started at %', GETDATE();

    DROP TABLE IF EXISTS mart.daily_revenue_stage;
    -- (in the real estate each mart build script is inlined here; the demo
    --  keeps them as separate files run in order 10, 11)

    RAISE INFO 'refresh finished at %', GETDATE();
END;
$$ LANGUAGE plpgsql;
