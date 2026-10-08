# 🌐 Threat Intelligence Integration: VirusTotal & Automated Active Response

This module provides automated **Cyber Threat Intelligence (CTI)** and **Active Response (SOAR)** capabilities for the Wazuh SIEM/EDR platform, following the official [Wazuh Threat Intelligence Documentation](https://documentation.wazuh.com/current/proof-of-concept-guide/detect-remove-malware-virustotal.html).

When File Integrity Monitoring (FIM / `syscheck`) detects a file created or modified in monitored directories (e.g. `/tmp`, `/root`), Wazuh automatically queries **VirusTotal**. If flagged as malware, Wazuh's Active Response engine immediately removes the threat from the endpoint.

---

## 🔑 How to Get a Free VirusTotal API Key

1. Create a free account at [virustotal.com](https://www.virustotal.com/).
2. Click on your profile icon in the top right $\rightarrow$ **API key**.
3. The Community tier allows 4 requests/minute and 500 requests/day.

---

## 🚀 Installation & Configuration

### 1. On Wazuh Server (`192.168.56.10`)

Add the following configuration blocks inside `/var/ossec/etc/ossec.conf`:

```xml
<ossec_config>
  <!-- VirusTotal Integration -->
  <integration>
    <name>virustotal</name>
    <api_key>YOUR_VIRUSTOTAL_API_KEY</api_key>
    <rule_id>100200,100201</rule_id>
    <alert_format>json</alert_format>
  </integration>

  <!-- Active Response Command -->
  <command>
    <name>remove-threat</name>
    <executable>remove-threat.sh</executable>
    <timeout_allowed>no</timeout_allowed>
  </command>

  <!-- Active Response Trigger -->
  <active-response>
    <disabled>no</disabled>
    <command>remove-threat</command>
    <location>local</location>
    <rules_id>87105</rules_id>
  </active-response>
</ossec_config>
```

Add the custom FIM and Active Response feedback rules into `/var/ossec/etc/rules/local_rules.xml`:

```xml
<group name="syscheck,pci_dss_11.5,nist_800_53_SI.7,">
    <rule id="100200" level="7">
        <if_sid>550</if_sid>
        <field name="file">/root|/tmp</field>
        <description>File modified in /root or /tmp directory.</description>
    </rule>
    <rule id="100201" level="7">
        <if_sid>554</if_sid>
        <field name="file">/root|/tmp</field>
        <description>File added to /root or /tmp directory.</description>
    </rule>
</group>

<group name="virustotal,">
  <rule id="100092" level="12">
    <if_sid>657</if_sid>
    <match>Successfully removed threat</match>
    <description>$(parameters.program) removed threat located at $(parameters.alert.data.virustotal.source.file)</description>
  </rule>

  <rule id="100093" level="12">
    <if_sid>657</if_sid>
    <match>Error removing threat</match>
    <description>Error removing threat located at $(parameters.alert.data.virustotal.source.file)</description>
  </rule>
</group>
```

Restart Wazuh Manager:
```bash
sudo systemctl restart wazuh-manager
```

### 2. On Linux Agent (`192.168.56.30`)

1. Install `jq`:
   ```bash
   sudo apt update && sudo apt install -y jq
   ```
2. Deploy `remove-threat.sh` to `/var/ossec/active-response/bin/remove-threat.sh` with permissions `750` and ownership `root:wazuh`:
   ```bash
   sudo chmod 750 /var/ossec/active-response/bin/remove-threat.sh
   sudo chown root:wazuh /var/ossec/active-response/bin/remove-threat.sh
   sudo ln -sf /var/ossec/active-response/bin/remove-threat.sh /var/ossec/active-response/bin/remove-threat
   ```
3. Restart Wazuh Agent:
   ```bash
   sudo systemctl restart wazuh-agent
   ```

---

## 🧪 Testing Automated Threat Removal

Drop an EICAR test file on the agent:
```bash
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' | sudo tee /tmp/malware_test.exe
```

### Alert & Response Flow:
1. **FIM Scan**: Rule `100201` triggers on the added file in `/tmp`.
2. **VirusTotal Query**: Wazuh Manager sends hash to VirusTotal.
3. **Malware Alert**: VirusTotal detects malicious file $\rightarrow$ Rule `87105` triggers (Level 12).
4. **Active Response**: `remove-threat.sh` executes locally on the agent and permanently removes `/tmp/malware_test.exe`.
5. **SOC Feedback**: Rule `100092` triggers on Wazuh Dashboard (*Successfully removed threat*).
