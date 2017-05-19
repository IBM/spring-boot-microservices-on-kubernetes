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
