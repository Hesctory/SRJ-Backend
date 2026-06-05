using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IStaffMemberRepository
{
    Task CreateAsync(DStaffMember staffMember, int personId);
    Task UpdateAsync(DStaffMember staffMember);
    Task<bool> ExistsAsync(int id);
    Task<bool> IsStaffMemberAsync(int personId);
    Task<bool> TryDeleteAsync(int id);
    Task ArchiveAsync(int id);
    Task UnarchiveAsync(int id);
}
