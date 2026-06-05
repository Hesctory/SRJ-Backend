using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IStaffMemberQueries
{
    Task<(List<StaffMemberListDTO> Items, int Total)> GetPagedAsync(int skip, int take, StaffMemberFilter? filter = null);
    Task<StaffMemberDetailDTO?> GetByIdAsync(int id);
}
