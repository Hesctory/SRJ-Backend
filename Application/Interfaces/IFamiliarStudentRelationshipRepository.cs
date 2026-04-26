namespace SRJBackend.Application.Interfaces;

public interface IFamiliarStudentRelationshipRepository
{
    Task<bool> ExistsByStudentIdAsync(int studentId);
    Task<List<int>> GetFamiliarIdsByStudentIdAsync(int studentId);
    Task DeleteByStudentIdAsync(int studentId);
}
