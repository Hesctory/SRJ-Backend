using SRJBackend.Application.DTOs;

namespace SRJBackend.Domain.Entities;

public record LoginResult
{
    public bool Success { get; init; }
    public string? Token { get; init; }
    public string? ErrorMessage { get; init; }
    public UserDTO? User { get; init; }

    public static LoginResult Ok(string token, UserDTO user) =>
        new() { Success = true, Token = token, User = user };

    public static LoginResult Fail(string message) =>
        new() { Success = false, ErrorMessage = message };
}
