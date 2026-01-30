const https = require("https");
const { SSMClient, GetParameterCommand } = require("@aws-sdk/client-ssm");

const ssm = new SSMClient({ region: "eu-central-1" });

async function getKubeconfig() {
  try {
    const cmd = new GetParameterCommand({
      Name: "/k8s/kubeconfig",
      WithDecryption: true,
    });
    const result = await ssm.send(cmd);
    return JSON.parse(result.Parameter.Value);
  } catch (err) {
    if (err.name === "ParameterNotFound") {
      return null;
    }
    throw err;
  }
}

function k8sRequest(kubeconfig, path) {
  return new Promise((resolve, reject) => {
    const url = new URL(kubeconfig.server + path);
    const options = {
      hostname: url.hostname,
      port: url.port || 6443,
      path: url.pathname,
      method: "GET",
      ca: Buffer.from(kubeconfig.ca, "base64"),
      cert: Buffer.from(kubeconfig.clientCert, "base64"),
      key: Buffer.from(kubeconfig.clientKey, "base64"),
      rejectUnauthorized: true,
    };

    console.log(`Sending K8s request to: ${kubeconfig.server}${path}`);
    console.log("Options:", { ...options, ca: "...", cert: "...", key: "..." });

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          resolve(data);
        }
      });
    });
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error("K8s API request timed out"));
    });
    req.on("error", reject);
    req.end();
  });
}

async function getPods() {
  const kubeconfig = await getKubeconfig();
  if (!kubeconfig) return "No infrastructure alive. Please deploy first.";
  const data = await k8sRequest(kubeconfig, "/api/v1/pods");
  if (!data.items) return "No pods found or unexpected response.";

  const lines = data.items.map((pod) => {
    const name = pod.metadata.name;
    const ns = pod.metadata.namespace;
    const phase = pod.status.phase;
    return `\`${ns}/${name}\` - ${phase}`;
  });
  return lines.join("\n") || "No pods found.";
}

async function getNodes() {
  const kubeconfig = await getKubeconfig();
  if (!kubeconfig) return "No infrastructure alive. Please deploy first.";
  const data = await k8sRequest(kubeconfig, "/api/v1/nodes");
  if (!data.items) return "No nodes found or unexpected response.";

  const lines = data.items.map((node) => {
    const name = node.metadata.name;
    const ready = node.status.conditions.find((c) => c.type === "Ready");
    const status = ready && ready.status === "True" ? "Ready" : "NotReady";
    return `\`${name}\` - ${status}`;
  });
  return lines.join("\n") || "No nodes found.";
}

module.exports = { getPods, getNodes };
