abstract class IRepository<T> {
  Future<T> create(T entity);
  Future<List<T>> findAll();
  Future<T?> findById(dynamic id);
  Future<T> update(T entity);
  Future<void> delete(dynamic id);
}

abstract class ICrudRepository<T> extends IRepository<T> {
  Future<List<T>> findWithPagination(int page, int limit);
  Future<int> count();
}
