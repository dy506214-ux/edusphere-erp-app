const http = require("https");
const data = JSON.stringify({ email: "teacher1@edusphere.com", password: "Password@123" });
const options = {
  hostname: "edusphere-erp-frontend.onrender.com",
  port: 443,
  path: "/api/v1/auth/login",
  method: "POST",
  headers: { "Content-Type": "application/json", "Content-Length": data.length }
};
const req = http.request(options, (res) => {
  let body = "";
  res.on("data", (chunk) => body += chunk);
  res.on("end", () => {
    try {
      const loginData = JSON.parse(body);
      const token = loginData.token;
      const userId = loginData.user.id;
      
      const userOptions = {
        hostname: "edusphere-erp-frontend.onrender.com",
        port: 443,
        path: `/api/v1/users/${userId}`,
        method: "GET",
        headers: {
          "Accept": "application/json",
          "Authorization": `Bearer ${token}`
        }
      };
      
      const uReq = http.request(userOptions, (uRes) => {
        let uBody = "";
        uRes.on("data", (chunk) => uBody += chunk);
        uRes.on("end", () => {
          console.log("User Profile Status:", uRes.statusCode);
          console.log("User Profile Body:", uBody);
        });
      });
      uReq.end();
    } catch (e) {
      console.error(e);
    }
  });
});
req.write(data);
req.end();
