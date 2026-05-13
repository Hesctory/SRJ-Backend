namespace SRJBackend.Domain.ValueObjects;

public record IdentityDocument
{
    public int DocumentTypeId { get; }
    public string IdDocumentNumber { get; }

    public IdentityDocument(int documentTypeId, string idDocumentNumber)
    {
        if (documentTypeId <= 0)
            throw new ArgumentException("Document type is required.", nameof(documentTypeId));
        if (string.IsNullOrWhiteSpace(idDocumentNumber))
            throw new ArgumentException("Document number cannot be empty.", nameof(idDocumentNumber));

        DocumentTypeId = documentTypeId;
        IdDocumentNumber = idDocumentNumber;
    }
}
