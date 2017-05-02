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