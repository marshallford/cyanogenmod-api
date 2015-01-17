#!/usr/bin/ruby
require 'rubygems'
require 'bundler/setup'
# require your gems as usual
require 'httparty'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'deep_merger'

# time
timeNow = Time.new
$currentTime = timeNow.utc

# vars
baseDeviceURL = "https://download.cyanogenmod.org"
devices = []

# method that checks if website is valid/available and returns Nokogiri HTML object
def checkAndOpen(url)
	userAgent = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
	begin
		openURLpage = open(url, {'User-Agent' => userAgent})
	rescue OpenURI::HTTPError => ex
		File.open("log.txt","a") do |f|
	  		f.write(Time.new.utc.to_s + "    OpenURI Error: " + ex.to_s + "\n")
		end
		abort
	end
	# abort if page size is less than 10KB
	if (openURLpage.size * 0.001) < 10
		File.open("log.txt","a") do |f|
	  		f.write(Time.new.utc.to_s + "    Page Size Error: Page size is " + (openURLpage.size * 0.001).to_s + "KB\n")
		end
		abort
	end
	return Nokogiri::HTML(openURLpage)
end

# output folder
Dir.mkdir("output") unless File.exists?("output")

# get device list
deviceListPage = checkAndOpen(baseDeviceURL) # create Nokogiri object

deviceListPage.css("span.codename").each_with_index do |deviceName, index|
	# puts deviceName.text
	devices[index] = deviceName.text
end

# test smaller sample
devices = devices.last(3)

# loop through all devices
devices.each_with_index do |device, index|

	# open the particular device's page
	devicePage = checkAndOpen(baseDeviceURL + "/?device=" + device)

	# get releaseType for each release item
	releaseType = []
	devicePage.css("td:nth-child(2)").each_with_index do |releaseItem, releaseIndex|
		releaseType[releaseIndex] = releaseItem.text
	end

	# get buildId and downloadUrl for each release item
	buildId = []
	downloadUrl = []
	devicePage.css("b+ a").each_with_index do |releaseItem, releaseIndex|
		buildId[releaseIndex] = releaseItem.text.gsub(".zip", "")
		downloadUrl[releaseIndex] = baseDeviceURL + releaseItem.attr('href')
	end

	# get md5 for each release item
	md5 = []
	devicePage.css("td+ td .md5").each_with_index do |releaseItem, releaseIndex|
		md5[releaseIndex] = releaseItem.text.split(" ")[1].split(" ")[0].strip
	end

	# get size for each release item
	size = []
	devicePage.css("td:nth-child(4)").each_with_index do |releaseItem, releaseIndex|
		size[releaseIndex] = releaseItem.text
	end

	# get dateAdded property for each release item
	dateAdded = []
	devicePage.css("td:nth-child(5)").each_with_index do |releaseItem, releaseIndex|
		dateAdded[releaseIndex] = releaseItem.text
	end

	# start the creation of the hash
	hash = {:resultCount => releaseType.length.to_s, :lastUpdated => Time.new.utc }

	# write out hash
	releaseType.each_with_index do |releaseItem, releaseIndex|
		source = {:results => [ {:releaseType => releaseType[releaseIndex], :buildId => buildId[releaseIndex], :downloadUrl => downloadUrl[releaseIndex], :md5 => md5[releaseIndex], :size => size[releaseIndex], :dateAdded => dateAdded[releaseIndex] }]}
		DeepMerger.deep_merge!(hash, source)
	end
	# save hash as json to file
	File.open("output/" + device + ".json","w") do |f|
  		f.write(JSON.pretty_generate(JSON.parse(hash.to_json)))
	end

	# create main json file
	hash = {:deviceCount => devices.length.to_s, :lastUpdated => Time.new.utc }
	devices.each_with_index do |item, index|
		source = {:deviceList => [ {:deviceName => devices[index]}]}
		DeepMerger.deep_merge!(hash, source)
	end
	# save hash as json to file
	File.open("device-list.json","w") do |f|
  		f.write(JSON.pretty_generate(JSON.parse(hash.to_json)))
	end
end
