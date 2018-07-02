# Copyright 2018 IBM Corp. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

import requests
import json
import time
import random

#Wait for the webserver to start
print "sleeping for 25 to wait for webserver"
time.sleep(25)

while True:

	transactionAmount = round(random.uniform(1000, 100000),2)
	interestRate = .04232 #random.uniform(.04634)

	print "Computing interest for transaction with amount: " + str(transactionAmount) + " and interestRate: " + str(interestRate)
	transaction = {'amount': str(transactionAmount), 'interestRate': str(interestRate)}
	headers = {'Content-type': 'application/json', 'Accept': 'text/plain'}
	response = requests.post("http://compute-interest-api:8080/computeinterest", data=json.dumps(transaction), headers=headers)	
	print response.text
	time.sleep(1)
