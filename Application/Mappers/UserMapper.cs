using SRJBackend.Application.DTOs;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Mappers;

public static class UserMapper
{
    public static UserDTO ToDTO(DUser user) => new UserDTO
    {
        Id = user.Id,
        Name = user.FullName ?? string.Empty,
        Email = user.Email!,
        Phone = user.Phone ?? string.Empty,
        Roles = user.Roles
    };
}
