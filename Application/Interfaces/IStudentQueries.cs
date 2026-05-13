using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IStudentQueries
{
    Task<(List<StudentListDTO> Items, int Total)> GetPagedAsync(int skip, int take, StudentFilter? filter = null);
    Task<StudentDetailDTO?> GetByIdAsync(int id);
}
