import subprocess
import re
import os
import sys
import csv
import xml.etree.ElementTree as ET
import ipaddress

subnets = []

if os.geteuid() != 0:
    print("This script requires root (sudo) privileges to run.")
    sys.exit(1)  # Exit the script with an error code

def validate_subnet(subnet):
    try:
        _ = ipaddress.ip_network(subnet, strict=False)
        return True
    except ValueError:
        return False

def network_selection():
    global subnets
    subnets = []  # Reset in case of re-runs

    num_of_networks = int(input("Input the number of networks you want to map: "))

    for i in range(num_of_networks):
        while True:
            subnet = input(f"Please input your subnet #{i + 1} (e.g., 192.168.1.0/24): ").strip()
            if not validate_subnet(subnet):
                print("❌ Invalid subnet format. Please enter a valid CIDR (e.g., 192.168.0.0/24).")
                continue
            name = input(f"Input a name for the subnet #{i + 1}: ").strip()
            subnets.append({"subnet": subnet, "name": name})
            break

    print("\nYou entered the following subnets:")
    for i, net in enumerate(subnets, 1):
        print(f"{i}: {net['subnet']} ({net['name']})")

    verification()

def scan_ports_nmap(subnet):
    filename_prefix = subnet.replace("/", "_").replace(".", "-")
    xml_file = f"nmap_{filename_prefix}.xml"
    csv_file = f"nmap_{filename_prefix}.csv"

    try:
        print(f"\nRunning Nmap scan on {subnet}...")

        is_single_host = not ('/' in subnet) or subnet.endswith('/32')
        subnet_size = 1

        if '/' in subnet:
            cidr = int(subnet.split('/')[-1])
            if cidr < 32:
                subnet_size = 2 ** (32 - cidr)

        if is_single_host:
            cmd = ["nmap", "-sS", "-sV", "-p-", "-T4", "-O", "--osscan-guess", "-R", "-Pn", subnet, "-oX", xml_file]
            timeout_value = 120
        elif subnet_size <= 8:
            cmd = ["nmap", "-sS", "-sV", "-p 21-23,25,53,80,443,3389,8080,8443", "-T4", "-O", "--osscan-guess", "-R", "-Pn", subnet, "-oX", xml_file]
            timeout_value = 800
        else:
            cmd = ["nmap", "-sS", "-sV","-F", "-T5", "-R", "-O", "--osscan-guess", "-Pn", subnet, "-oX", xml_file]
            timeout_value = 10000

        print(f"Running scan with timeout of {timeout_value} seconds...")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_value)

        if result.returncode != 0:
            print(f"Nmap exited with code {result.returncode}")
            print("STDOUT:\n", result.stdout[:500])
            print("STDERR:\n", result.stderr[:500])
            return None


        if not os.path.exists(xml_file):
            print(f"XML file not created: {xml_file}")
            return None

        ports = re.findall(r"(\d+)/open", result.stdout)
        print("Open Ports Found:", ", ".join(ports) if ports else "None")

    except subprocess.TimeoutExpired:
        print(f"Nmap scan timed out after {timeout_value} seconds")
        if os.path.exists(xml_file) and os.path.getsize(xml_file) > 100:
            print("Using partial results from the scan...")
        else:
            print("No usable scan results available")
            return None

    except FileNotFoundError:
        print("Nmap is not installed. Install it with: sudo apt install nmap -y")
        return None

    except Exception as e:
        print(f"Error running Nmap: {e}")
        return None

    if os.path.exists(xml_file) and os.path.getsize(xml_file) > 0:
        success = convert_to_csv(xml_file, csv_file)
        if success and os.path.exists(csv_file):
            return csv_file
        else:
            print("Converting directly from XML...")
            return xml_file
    else:
        print(f"No valid XML file found at {xml_file}")
        return None

def convert_to_csv(xml_file, csv_file):
    if not os.path.exists(xml_file):
        print(f"XML file not found: {xml_file}")
        return False

    xml_size = os.path.getsize(xml_file)
    if xml_size == 0:
        print(f"XML file is empty: {xml_file}")
        return False

    print(f"XML file size: {xml_size} bytes")

    if not os.path.exists("xml2csv.py"):
        print("Missing xml2csv.py, downloading it now...")
        process = subprocess.run("git clone https://github.com/NetsecExplained/Nmap-XML-to-CSV.git", shell=True, capture_output=True, text=True)

        if process.returncode != 0:
            print("Failed to clone the repo:")
            print(process.stderr)
            return False

        try:
            os.rename("Nmap-XML-to-CSV/xml2csv.py", "xml2csv.py")
        except FileNotFoundError:
            print("Download succeeded but xml2csv.py not found in the repo.")
            return False

    command = f"python3 xml2csv.py -f {xml_file} -csv {csv_file}"
    process = subprocess.run(command, shell=True, capture_output=True, text=True)

    if process.returncode != 0:
        print(f"Error converting to CSV: {process.stderr}")
        return False
    else:
        print(f"CSV generated: {csv_file}")
        if os.path.exists(csv_file) and os.path.getsize(csv_file) > 0:
            print(f"CSV file created successfully: {os.path.getsize(csv_file)} bytes")
            return True
        else:
            print("CSV file creation failed or file is empty")
            return False

def verification():
    subnet_selections = input("\nAre these subnet choices correct? y/n: ")
    if subnet_selections.lower() == "y":
        print("Continuing with Nmap scans...\n")
        for net in subnets:
            if "hosts" in net:
                del net["hosts"]

        for i, net in enumerate(subnets):
            result_file = scan_ports_nmap(net["subnet"])
            if result_file:
                if result_file.endswith('.csv'):
                    net["hosts"] = parse_hosts_from_csv(result_file)
                else:
                    net["hosts"] = parse_hosts_from_xml(result_file)
                print(f"Found {len(net['hosts'])} hosts in subnet '{net['name']}'")
            else:
                print(f"No valid scan results for subnet '{net['name']}'")
                net["hosts"] = []

        generate_drawio(subnets)
    else:
        print("Restarting application...\n")
        subnets.clear()
        network_selection()

def parse_hosts_from_csv(csv_file):

    hosts_dict = {}
    if not os.path.exists(csv_file):
        print(f"CSV not found: {csv_file}")
        return []

    with open(csv_file, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ip = row.get("IP", "").strip()
            hostname = row.get("Hostname", "").strip()
            os_info = row.get("OS", "").strip()
            service = row.get("Service", "").strip()

            if not ip:
                continue

            if ip not in hosts_dict:
                hosts_dict[ip] = {
                    "ip": ip,
                    "hostname": hostname,
                    "os": os_info,
                    "services": set()
                }

            if service:
                hosts_dict[ip]["services"].add(service)

            # Prefer non-empty hostname or OS
            if hostname:
                hosts_dict[ip]["hostname"] = hostname
            if os_info:
                hosts_dict[ip]["os"] = os_info

    # Create display_name and convert to list
    final_hosts = []
    for host in hosts_dict.values():
        display_name = f"{host['hostname']} ({host['ip']})" if host["hostname"] else host["ip"]
        if host["os"]:
            display_name += f"\nOS: {host['os']}"
        if host["services"]:
            services = sorted(host["services"])
            display_name += f"\nServices: {', '.join(services[:3])}"
            if len(services) > 3:
                display_name += f" (+{len(services)-3} more)"

        host["display_name"] = display_name
        final_hosts.append(host)

    return final_hosts


def parse_hosts_from_xml(xml_file):
    import os
    import xml.etree.ElementTree as ET

    if not os.path.exists(xml_file):
        print(f"XML file not found: {xml_file}")
        return []

    hosts_dict = {}

    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        for host in root.findall('./host'):
            ip = ""
            hostname = ""
            os_info = ""
            services = set()

            address = host.find('./address[@addrtype="ipv4"]')
            if address is not None:
                ip = address.get('addr', '')
            if not ip:
                continue

            # Hostname
            hostname_elem = host.find('./hostnames/hostname')
            if hostname_elem is not None:
                hostname = hostname_elem.get('name', '')

            # OS Info
            os_match = host.find('.//os/osmatch')
            if os_match is not None:
                os_info = os_match.get('name', '')

            # Services
            for port in host.findall('.//port'):
                port_id = port.get('portid', '')
                service_elem = port.find('service')
                if service_elem is not None:
                    service_name = service_elem.get('name', '')
                    if port_id and service_name:
                        services.add(f"{service_name} ({port_id})")

            if ip not in hosts_dict:
                hosts_dict[ip] = {
                    "ip": ip,
                    "hostname": hostname,
                    "os": os_info,
                    "services": services
                }
            else:
                hosts_dict[ip]["services"].update(services)
                if hostname:
                    hosts_dict[ip]["hostname"] = hostname
                if os_info:
                    hosts_dict[ip]["os"] = os_info

        # Create display_name and convert to list
        final_hosts = []
        for host in hosts_dict.values():
            display_name = f"{host['hostname']} ({host['ip']})" if host["hostname"] else host["ip"]
            if host["os"]:
                display_name += f"\nOS: {host['os']}"
            if host["services"]:
                services = sorted(host["services"])
                display_name += f"\nServices: {', '.join(services[:3])}"
                if len(services) > 3:
                    display_name += f" (+{len(services)-3} more)"

            host["display_name"] = display_name
            final_hosts.append(host)

        return final_hosts

    except Exception as e:
        print(f"Error parsing XML: {e}")
        return []


def generate_drawio(networks, output_file="network_topology.drawio"):
    print("\nVerifying subnet data before generating diagram:")
    for i, net in enumerate(networks):
        host_count = len(net.get("hosts", []))
        print(f"Subnet {i+1}: {net['name']} ({net['subnet']}) - {host_count} hosts")

    mxfile = ET.Element("mxfile", host="app.diagrams.net")
    diagram = ET.SubElement(mxfile, "diagram", name="Network Topology")
    mxGraphModel = ET.SubElement(diagram, "mxGraphModel")
    root = ET.SubElement(mxGraphModel, "root")

    ET.SubElement(root, "mxCell", id="0")
    ET.SubElement(root, "mxCell", id="1", parent="0")

    x = 20
    y = 20
    subnet_width = 300
    host_height = 30
    spacing = 100
    id_counter = 2

    for net in networks:
        subnet_id = str(id_counter)
        id_counter += 1
        subnet_hosts = net.get("hosts", [])
        subnet_height = max(200, 60 + (len(subnet_hosts) * (host_height + 5)))
        box_style = "swimlane;whiteSpace=wrap;html=1;startSize=40;fillColor=#DAE8FC;strokeColor=#6C8EBF;rounded=1;"
        subnet_cell = ET.SubElement(root, "mxCell", id=subnet_id, value=f"{net['name']} ({net['subnet']})", style=box_style, vertex="1", parent="1")
        ET.SubElement(subnet_cell, "mxGeometry", attrib={
            "x": str(x),
            "y": str(y),
            "width": str(subnet_width),
            "height": str(subnet_height),
            "as": "geometry"
        })

        host_y_offset = 50
        for host in subnet_hosts:
            host_id = str(id_counter)
            id_counter += 1
            host_style = "rounded=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;fontSize=10;"
            host_cell = ET.SubElement(root, "mxCell", id=host_id, value=host["display_name"], style=host_style, vertex="1", parent=subnet_id)
            ET.SubElement(host_cell, "mxGeometry", attrib={
                "x": "10",
                "y": str(host_y_offset),
                "width": str(subnet_width - 20),
                "height": str(host_height),
                "as": "geometry"
            })
            host_y_offset += host_height + 5

        y += subnet_height + spacing

    tree = ET.ElementTree(mxfile)
    with open(output_file, "wb") as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
        tree.write(f, encoding="utf-8")

    print(f"\n✅ Draw.io file with hosts generated: {output_file}")


if __name__ == "__main__":
    network_selection()
