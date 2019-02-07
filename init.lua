local mt_stat ={}

mt_stat.http = minetest.request_http_api()
mt_stat.url = minetest.settings:get("mt_stat.url") or "http://localhost:8086"
mt_stat.uptime = minetest.settings:get("mt_stat.uptime") or 10
mt_stat.db = minetest.settings:get("mt_stat.db") or "minetest"
mt_stat.timeout = minetest.settings:get("mt_stat.timeout") or 30
-- For secure connect set header value (Authorization: Basic bG9naW46cGFzc3dvcmQ=)
-- where bG9naW46cGFzc3dvcmQ= is the base64(login:password)
mt_stat.header = minetest.settings:get("mt_stat.header") or nil

function mt_stat.avg_value(players,v)
    local m = 0
    for _,player in ipairs(players) do
        local cp = minetest.get_player_information(player:get_player_name())
        m = m + cp[v]
    end
    return m / #players
end

function mt_stat.send_metrics()
    mt_stat.measurements = {}
    local players = minetest.get_connected_players()
    mt_stat.measurements.players_online = #players
    mt_stat.measurements.users_min_rtt = mt_stat.avg_value(players,"min_rtt")
    mt_stat.measurements.users_max_rtt = mt_stat.avg_value(players,"max_rtt")
    mt_stat.measurements.users_min_jitter = mt_stat.avg_value(players,"min_jitter")
    mt_stat.measurements.users_max_jitter = mt_stat.avg_value(players,"max_jitter")
    mt_stat.measurements.users_conn_uptime = mt_stat.avg_value(players,"connection_uptime")
    mt_stat.measurements.max_lag = string.match(minetest.get_server_status(), "max_lag=(.-), cli")
    mt_stat.measurements.game_time = minetest.get_timeofday() * 24000
    mt_stat.measurements.server_uptime = minetest.get_server_uptime()
    local united_data = "mt_stat "
    local t = ""
    for key,value in pairs(mt_stat.measurements) do
        united_data = united_data..t..string.format('%s=%02f',key,value)
        t = ","
    end
    --print(united_data)
    mt_stat.request_http("/write?db="..mt_stat.db, united_data)
    minetest.after(mt_stat.uptime, mt_stat.send_metrics)
end

function mt_stat.request_http(url,pd)
    local req = {url = mt_stat.url..url, post_data = pd, extra_headers = {mt_stat.header}, timeout = mt_stat.timeout}
    mt_stat.http.fetch(req,	function(result)
        if result.succeeded and result.code == 200 then
            if req.post_data.q == "SHOW DATABASES" and string.find(result.data, mt_stat.db) then
                minetest.after(mt_stat.uptime, mt_stat.send_metrics)
                minetest.log("mt_stat: Loaded... [OK]")
            elseif req.post_data.q == "SHOW DATABASES" and not string.find(result.data, mt_stat.db) then
                mt_stat.request_http("/query",{q="CREATE DATABASE "..mt_stat.db})
                minetest.log("mt_stat: Create database "..mt_stat.db.."!")
            elseif req.post_data.q == "CREATE DATABASE "..mt_stat.db then
                mt_stat.request_http("/query",{q="SHOW DATABASES"})
                minetest.log("mt_stat: Database created!")
            end
        end
    end)
end

if mt_stat.http then
    mt_stat.request_http("/query",{q="SHOW DATABASES"})
else 
    minetest.log("mt_stat: Please setup (secure.http_mod = mt_stat) in minetest.conf")
end