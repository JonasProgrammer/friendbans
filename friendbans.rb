#!/usr/bin/env ruby
require 'json'
require 'rest-client'
require 'colorize'
require 'optparse'

AUTH_KEY = ENV['STEAM_API_KEY']
unless AUTH_KEY
  puts 'Set STEAM_API_KEY environment variable to your steam API key!'.red
  exit 1
end

profiles       = []
$order         = nil
$combine_count = 50

OptionParser.new do |opts|
  opts.banner = 'Usage: firendbans.rb -p profile [-o order]'

  opts.on('-p', '--profile PROFILE', 'Specifies which profile(s) to check') do |prf|
    profiles << prf
  end

  opts.on('-c', '--combine X', 'Combine X (1..200, def. 50) steam IDs per call') do |c|
    if c.to_i > 0 && c.to_i <= 200
      $combine_count = c.to_i
    else
      puts 'Invalid combine count, using default'.red
    end
  end

  opts.on('-o', '--order [ASC|DESC]', 'Specifies the order of ban dates to print') do |o|
    if o.strip.upcase == 'ASC'
      $order = :asc
    elsif o.strip.upcase == 'DESC'
      $order = :desc
    else
      puts "Invalid order #{o}".red
      exit 2
    end
  end

  opts.on('-h', '--help', 'Prints help') do
    puts opts
    exit
  end
end.parse!

unless profiles.length >= 1
  puts 'At least 1 profile ID required!'.red
  exit 3
end

def get_friends(steam_id)
  friendsresp = RestClient.get 'https://api.steampowered.com/ISteamUser/GetFriendList/v0001/', { params: { steamid: steam_id, relationship: 'friend', key: AUTH_KEY } }

  unless friendsresp.code == 200
    puts "Error getting friends for #{steam_id}!".red
  end

  JSON.parse(friendsresp.to_str)['friendslist']['friends'].map {|f| f['steamid']}
end

def get_bans(ids)
  bans = []

  ids.each_slice($combine_count) do |idslice|
    ids_param = idslice.join ','
    banresp  = RestClient.get 'https://api.steampowered.com/ISteamUser/GetPlayerbans/v0001/', { params: { steamids: ids_param, key: AUTH_KEY } }
    if banresp.code == 200
      JSON.parse(banresp.to_str)['players'].each do |b|
        bans << { banned: b['VACBanned'], days: b['DaysSinceLastBan'], vac: b['NumberOfVACBans'], game: b['NumberOfGameBans'], id: b['SteamId'] }
      end
    else
      puts "Error getting bans for steamids #{ids_param}!".red
    end
  end

  bans
end

def get_user_details(ids)
  detail = {}

  ids.each_slice($combine_count) do |idslice|
    ids = idslice.join ','
    begin
      uresp = RestClient.get 'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/', { params: { steamids: ids, key: AUTH_KEY } }
      JSON.parse(uresp.to_str)['response']['players'].each do |u|
        detail[u['steamid']] = { id: u['steamid'], name: u['personaname'], url: u['profileurl'] }
      end
    rescue
      puts "\tError getting user details for #{ids}".red
    end
  end

  detail
end

def analyze_friend_bans(steam_id)
  friends = get_friends(steam_id)

  bans = get_bans friends
  bans.select! {|b| b && (b[:banned] || b[:vac] > 0 || b[:game] > 0)}

  details = get_user_details bans.map {|b| b[:id]}

  bans.map! do |b|
    if details[b[:id]]
      bans[:detail] = details[b[:id]]
    end
  end

  if $order == :asc
    bans.sort! {|b1, b2| b1[:days] <=> b2[:days]}
  elsif order == :desc
    bans.sort! {|b1, b2| b2[:days] <=> b1[:days]}
  end

  return friends.length, bans
end

profiles.map! do |p|
  id = nil

  m = /https?:\/\/steamcommunity.com\/profiles\/(\d+)/.match p
  if m && m[1]
    id = m[1]
  else
    sanitized = p
    m         = /https?:\/\/steamcommunity.com\/id\/(\d+)/.match p
    if m && m[1]
      sanitized = m[1]
    end

    vanityresp = RestClient.get 'https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/', { params: { vanityurl: sanitized, key: AUTH_KEY } }
    if vanityresp.code == 200
      resp    = JSON.parse(vanityresp.to_str)['response']
      success = resp['success'].to_i
      if success == 1
        id = resp['steamid']
      else
        puts "Potential invalid response (expected 1 or 42): #{resp.inspect}".yellow unless success == 42
        m = /\d+/.match p
        if m
          id = m[0]
        else
          puts "Invalid profile specified: #{p}".red
        end
      end
    else
      puts "Error resolving profile url #{p}!".red
    end
  end

  id
end

get_user_details(profiles.reject(&:nil?)).values.flatten.sort{|p1, p2| p1[:name] <=> p2[:name]}.each do |player|
  banner = <<-EOF
#############################################################
# Player Report for: #{player[:id]}
#############################################################
# #{player[:name]}
# #{player[:url]}
#############################################################
EOF
  puts banner.green

  total_friends, bans = analyze_friend_bans player[:id]
  puts "Total bans: #{bans.length} / #{total_friends}".red

  bans.each do |b|
    puts "#{b[:id]} [#{b[:days]} days -- #{b[:vac] + b[:game]} total]".blue
    if b[:detail]
      puts "\tName:\t#{b[:detail][:name].yellow}"
      puts "\tURL:\t#{b[:detail][:url].yellow}"
    else
      puts "\tError getting user detail".red
    end
    puts "\tDays:\t#{b[:days].to_s.yellow}"
    puts "\t#VAC:\t#{b[:vac].to_s.red}"
    puts "\t#Game:\t#{b[:game].to_s.red}"
  end

  puts "\n\n"
end