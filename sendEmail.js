// Copyright 2018 IBM Corp. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

'use strict';
var nodemailer = require('nodemailer');

function main(params) {



// create transporter object using the default SMTP transport
let transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: params.sender,
        pass: params.password
    }
});
console.log('SMTP Configured??');

// setup email data
let mailOptions = {
    from: '"' + params.sender + '" <' + params.sender + '>', // sender address
    to: params.receiver, // list of receivers
    subject: params.subject, // Subject line
    text: params.text, // plain text body
};
console.log("Mail configured");


//send mail
var promise = new Promise(function (resolve, reject) {
transporter.sendMail(mailOptions, (error, info) => {
    if (error) {
        console.log(error);
        reject(error);
    }
    else {
        console.log('Message %s sent: %s', info.messageId, info.response);
        resolve(info);
    }
});
});
return promise;

}
