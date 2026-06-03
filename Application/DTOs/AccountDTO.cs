namespace SRJBackend.Application.DTOs;

public class AccountDTO
{
    public int id { get; set; }
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public int? ParentAccountId { get; set; }
    public string? PrintCode { get; set; }
}

public class CreateAccountDTO
{
    public string Code { get; set; } = null!;
    public string Name { get; set; } = null!;
    public int? ParentAccountId { get; set; }
    public string? PrintCode { get; set; }
}
