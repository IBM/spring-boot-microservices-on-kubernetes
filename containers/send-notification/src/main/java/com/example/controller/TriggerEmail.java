package com.example.controller;

import javax.mail.internet.MimeMessage;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

@RestController
public class TriggerEmail {

	@Autowired
	private JavaMailSender mailSender;

	@Value("${spring.mail.username}")
	private String sender;

	@Value("${trigger.mail.receiver}")
	private String receiver;

	@Value("${trigger.slack.url}")
	private String slack_url;

	@Value("${trigger.slack.message}")
	private String slack_message;

	@Value("${trigger.email.url}")
	private String email_url;
	
	@Value("${spring.mail.password}")
	private String password;

	@RequestMapping(path = "/email", method = RequestMethod.POST)
	private String send() {
		MimeMessage mail = mailSender.createMimeMessage();
		MimeMessageHelper helper = new MimeMessageHelper(mail);
		
		try {
			if (!email_url.isEmpty()) {
				helper.setTo(receiver);
				helper.setFrom(sender);
				helper.setReplyTo(sender);
				helper.setSubject("Office-Space Notification");
				helper.setText("Account Balance is now over $50,000");
				mailSender.send(mail);
			}
			else {
				RestTemplate rest = new RestTemplate();
				HttpHeaders headers = new HttpHeaders();
				String server = email_url;
				headers.add("Content-Type", "application/json");
				headers.add("Accept", "*/*");
				String json = "{\"text\": \"" + slack_message + "\",\"sender\": \"" + sender + "\",\"receiver\": \"" + receiver + "\",\"password\": \"" + password + "\",\"subject\": \"Office-Space Notification\"}";

				HttpEntity<String> requestEntity = new HttpEntity<String>(json, headers);
				ResponseEntity<String> responseEntity = rest.exchange(server, HttpMethod.POST, requestEntity, String.class);
			}


			if (!slack_url.isEmpty()) {
				RestTemplate rest = new RestTemplate();
				HttpHeaders headers = new HttpHeaders();
				String server = slack_url;
				headers.add("Content-Type", "application/json");
				headers.add("Accept", "*/*");
				String json = "{\"text\": \"" + slack_message + "\"}";

				HttpEntity<String> requestEntity = new HttpEntity<String>(json, headers);
				ResponseEntity<String> responseEntity = rest.exchange(server, HttpMethod.POST, requestEntity, String.class);
			}

			return "{\"message\": \"OK\"}";
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return "{\"message\": \"Error\"}";
		}
	}

	@RequestMapping(path = "/triggertest", method = RequestMethod.POST)
	private String trigger() {
		RestTemplate rest = new RestTemplate();
		HttpHeaders headers = new HttpHeaders();
		String server = "http://localhost:8080/email";
		headers.add("Content-Type", "application/json");
	    headers.add("Accept", "*/*");
		String json = "{}";

		HttpEntity<String> requestEntity = new HttpEntity<String>(json, headers);
	    ResponseEntity<String> responseEntity = rest.exchange(server, HttpMethod.POST, requestEntity, String.class);
	    return responseEntity.getBody();
	}
}
