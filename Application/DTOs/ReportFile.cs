namespace SRJBackend.Application.DTOs;

/// <summary>A generated report file ready to be streamed back to the client.</summary>
public record ReportFile(byte[] Content, string ContentType, string FileName);
