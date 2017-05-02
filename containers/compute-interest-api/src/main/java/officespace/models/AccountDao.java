package officespace.models;

import javax.transaction.Transactional;

import org.springframework.data.repository.CrudRepository;

/**
 * A DAO for the entity Account is simply created by extending the CrudRepository
 * interface provided by spring. The following methods are some of the ones
 * available from such interface: save, delete, deleteAll, findOne and findAll.
 * The magic is that such methods must not be implemented, and moreover it is
 * possible create new query methods working only by defining their signature!
 * 
 * @author John Zaccone
 */
@Transactional
public interface AccountDao extends CrudRepository<Account, Long> {

  /**
   * Return the account having the id or null if no user is found.
   * 
   * @param id the account id.
   */
  public Account findById(long id);

} 
