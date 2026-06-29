namespace SRJBackend.Domain.Entities;

public record LoginResult
{
    public bool Success { get; init; }
    public string? Token { get; init; }
    public string? ErrorMessage { get; init; }
    public DUser? User { get; init; }

    public static LoginResult Ok(string token, DUser user) =>
        new() { Success = true, Token = token, User = user };

    public static LoginResult Fail(string message) =>
        new() { Success = false, ErrorMessage = message };
}
