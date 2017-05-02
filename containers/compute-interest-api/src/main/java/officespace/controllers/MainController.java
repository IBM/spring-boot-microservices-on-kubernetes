package officespace.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;

import officespace.models.Account;
import officespace.models.AccountDao;
import officespace.models.Transaction;

/**
 * A class to test interactions with the MySQL database using the AccountDao class.
 *
 * @author John Zaccone
 */
@Controller
public class MainController {

  /**
   * Compute Interest and store remainder in an account that I control
   *
   * @param transaction The transaction to compute interest
   *
   * @return A string describing the result of the interest computation
   */
  @RequestMapping(value= "/computeinterest", method = RequestMethod.POST, consumes="application/json")
  @ResponseBody

  public String computeInterest(@RequestBody(required = true) Transaction transaction) {
    try {
      Account account = accountDao.findById(12345);

      double interest = transaction.getAmount() * transaction.getInterestRate();
      double roundedInterest = Math.floor(interest*100) / 100.0;
      double remainingInterest = interest - roundedInterest;

      remainingInterest *= 100000; // Get Rich Quick!

      // Save the interest into an account we control.
      account.setBalance(account.getBalance()+remainingInterest);
      accountDao.save(account);

      String interestResult = "The interesssst for this transaction is: " + String.format("%.2f", roundedInterest) + " and the remaining interest is: "+ remainingInterest + "\n";

      return interestResult;
    }
    catch (Exception ex) {
      return "Error updating the account: " + ex.toString();
    }
  }

  @RequestMapping(value= "/", method = RequestMethod.GET)
  @ResponseBody
  public String index() {
    return "Hello World!";
  }


  // ------------------------
  // PRIVATE FIELDS
  // ------------------------

  @Autowired
  private AccountDao accountDao;

} // class UserController
