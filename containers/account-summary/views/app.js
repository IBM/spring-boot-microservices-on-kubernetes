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

var app = angular.module('accountSummary', []);
var socket = io.connect({transports:['polling']});

app.controller('accountBalanceCtrl', function($scope){

  var updateAccountSummary = function(){
    socket.on('account', function (json) {
       data = JSON.parse(json);
       $scope.$apply(function () {
         $scope.total = data.balance;
       });
    });
  };

  var init = function(){
    document.body.style.opacity=1;
    updateAccountSummary();
  };
  socket.on('message',function(data){
    init();
  });
});
