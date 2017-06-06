const os = require('os');
const express = require('express');
const app = express();
const port = 9000;

app.get('/', (req, res) => {
  res.json({ 
    instance: 'hello micro-2 , waly, test #1',
    hostname: os.hostname()
  });
});

app.listen(port, () => {
  console.log(`Micro #2 listening on port ${port}`);
});
